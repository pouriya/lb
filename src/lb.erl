%%% --------------------------------------------------------------------
%%% BSD 3-Clause License
%%%
%%% Copyright (c) 2017-2018, Pouriya Jahanbakhsh
%%% (pouriya.jahanbakhsh@gmail.com)
%%% All rights reserved.
%%%
%%% Redistribution and use in source and binary forms, with or without
%%% modification, are permitted provided that the following conditions
%%% are met:
%%%
%%% 1. Redistributions of source code must retain the above copyright
%%% notice, this list of conditions and the following disclaimer.
%%%
%%% 2. Redistributions in binary form must reproduce the above copyright
%%% notice, this list of conditions and the following disclaimer in the
%%% documentation and/or other materials provided with the distribution.
%%%
%%% 3. Neither the name of the copyright holder nor the names of its
%%% contributors may be used to endorse or promote products derived from
%%% this software without specific prior written permission.
%%%
%%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
%%% "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
%%% LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
%%% FOR A  PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
%%% COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
%%% INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
%%% BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
%%% LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
%%% CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
%%% LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
%%% ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
%%% POSSIBILITY OF SUCH DAMAGE.
%%% --------------------------------------------------------------------
%% @author   Pouriya Jahanbakhsh <pouriya.jahanbakhsh@gmail.com>
%% @version  17.6.12
%% @doc
%%           Load-Balancer for spreading messages to processes and
%%           ports.
%% @end
%% ---------------------------------------------------------------------


-module(lb).
-author("pouriya.jahanbakhsh@gmail.com").


%% ---------------------------------------------------------------------
%% Exports:





%% API:
-export([start_link/0
        ,start_link/1
        ,start_link/2

        ,send/2
        ,send/3
        ,send_sync/2
        ,send_sync/3

        ,send_async/2
        ,send_async/3

        ,subscribe/1
        ,subscribe/2

        ,unsubscribe/1
        ,unsubscribe/2

        ,get_object/1
        ,get_objects/1]).





%% 'proc_lib' callbacks:
-export([init/2
        ,init/3]).





%% 'sys' callbacks:
-export([system_code_change/4
        ,system_continue/3
        ,system_get_state/1
        ,system_replace_state/2
        ,system_terminate/4]).





%% ---------------------------------------------------------------------
%% Records & Macros & Includes:





-record(lb_state_record, {name = erlang:self()
                         ,objects = []
                         ,object = undefined}).
-define(STATE, lb_state_record).





-define(DEFAULT_START_OPTIONS, []).
-define(DEFAULT_DEBUG_OPTIONS, []).
-define(DEFAULT_TIMEOUT, 5000).
-define(DEFAULT_SPAWN_OPTIONS, []).
-define(ONE_FOR_ONE, 'one_for_one').
-define(ONE_FOR_ALL, 'one_for_all').
-define(GEN_CAST, '$gen_cast').
-define(GEN_CALL, '$gen_call').
-define(GET_OBJECT, 'get_object').
-define(GET_OBJECTS, 'get_objects').
-define(SUBSCRIBE, 'subscribe').
-define(UNSUBSCRIBE, 'unsubscribe').





%% ---------------------------------------------------------------------
%% Types:





-type lb() :: pid() | atom().

-type start_options() :: [] | [start_option()].
-type  start_option() :: {'debug', [] | [sys:dbg_opt()]}
                       | {'timeout', timeout()}
                       | {'spanw_opts', [] | [proc_lib:spawn_option()]}.

-type start_return() :: {'ok', pid()} | {'error', term()}.

-type register_name() :: {'local', atom()}
                       | {'global', atom()}
                       | {'via', module(), term()}.

-type object() :: pid() | port().

-type send_type() :: 'one_for_one' | 'one_for_all'.

-type error() :: {'error', {Reason::atom(), ErrorParams::list()}}.





%% ---------------------------------------------------------------------
%% API:





-spec
start_link() ->
    start_return().
%% @doc
%%      Starts and links a load-balancer.
%% @end
start_link() ->
    {DbgOpts, Timeout, SpawnOpts} = get_options(?DEFAULT_START_OPTIONS),
    proc_lib:start_link(?MODULE
                       ,init
                       ,[erlang:self(), DbgOpts]
                       ,Timeout
                       ,SpawnOpts).







-spec
start_link(Name_or_Opts::register_name() | start_options()) ->
    start_return().
%% @doc
%%      Starts and links a load-balancer.
%%      Argument can be Opts or registered name.
%% @end
start_link(Opts) when erlang:is_list(Opts) ->
    {DbgOpts, Timeout, SpawnOpts} = get_options(Opts),
    proc_lib:start_link(?MODULE
                       ,init
                       ,[erlang:self(), DbgOpts]
                       ,Timeout
                       ,SpawnOpts);
start_link(Name) when erlang:is_tuple(Name) ->
    {DbgOpts, Timeout, SpawnOpts} = get_options(?DEFAULT_START_OPTIONS),
    proc_lib:start_link(?MODULE
                       ,init
                       ,[erlang:self(), DbgOpts, Name]
                       ,Timeout
                       ,SpawnOpts).







-spec
start_link(register_name(), start_options()) ->
    start_return().
%% @doc
%%      Starts and links a load-balancer.
%%      Load-balancer will register its name.
%% @end
start_link(Name, Opts) when erlang:is_list(Opts) ->
    {DbgOpts, Timeout, SpawnOpts} = get_options(Opts),
    proc_lib:start_link(?MODULE
                       ,init
                       ,[erlang:self(), DbgOpts, Name]
                       ,Timeout
                       ,SpawnOpts).







-spec
subscribe(lb()) ->
    'ok'.
%% @equiv subscribe(LB, erlang:self())
%% @doc
%%      Subscribes caller to receiving messages from load-balancer.
%% @end
subscribe(LB) ->
    subscribe(LB, erlang:self()).







-spec
subscribe(lb(), object()) ->
    'ok'.
%% @doc
%%      Subscribes object to receiving messages from load-balancer.
%% @end
subscribe(LB, Object) ->
    gen_server:call(LB, {?SUBSCRIBE, Object}).







-spec
unsubscribe(lb()) ->
    'ok'.
%% @equiv unsubscribe(LB, erlang:self())
%% @doc
%%      Unsubscribes caller to receiving messages from load-balancer.
%% @end
unsubscribe(LB) ->
    unsubscribe(LB, erlang:self()).







-spec
unsubscribe(lb(), object()) ->
    'ok'.
%% @doc
%%      Unsubscribes object to receiving messages from load-balancer.
%% @end
unsubscribe(LB, Object) ->
    gen_server:call(LB, {?UNSUBSCRIBE, Object}).







-spec
send(lb(), term()) ->
    'ok' | error().
%% @equiv send_sync(LB, Msg) and send_sync(LB, Msg, one_for_one)
%% @doc
%%      sends one_for_one message to load-balancer synchronously.
%% @end
send(LB, Msg) ->
    send_sync(LB, Msg).







-spec
send(lb(), term(), send_type()) ->
    'ok' | error().
%% @equiv send_sync(LB, Msg, SendType)
%% @doc
%%      sends message to load-balancer synchronously with defined send 
%%      type.
%% @end
send(LB, Msg, SendType) ->
    send_sync(LB, Msg, SendType).







-spec
send_sync(lb(), term()) ->
    'ok' | error().
%% @doc
%%      sends one_for_one message to load-balancer synchronously.
%% @end
send_sync(LB, Msg) ->
    send_sync(LB, Msg, ?ONE_FOR_ONE).







-spec
send_sync(lb(), term(), send_type()) ->
    'ok' | error().
%% @doc
%%      sends message to load-balancer synchronously with defined send 
%%      type.
%% @end
send_sync(LB, Msg, SendType) ->
    gen_server:call(LB, {SendType, Msg}).







-spec
send_async(lb(), term()) ->
    'ok'.
%% @equiv send_async(LB, Msg, one_for_one)
%% @doc
%%      sends one_for_one message to load-balancer asynchronously.
%% @end
send_async(LB, Msg) ->
    send_async(LB, Msg, ?ONE_FOR_ONE).







-spec
send_async(lb(), term(), send_type()) ->
    'ok'.
%% @doc
%%      sends message to load-balancer asynchronously with defined send 
%%      type.
%% @end
send_async(LB, Msg, SendType) ->
    gen_server:cast(LB, {SendType, Msg}).







-spec
get_object(lb()) ->
    {'ok', object()} | error().
%% @doc
%%      returns an object. <br/>
%%      in next call returns next object an so on.
%% @end
get_object(LB) ->
    gen_server:call(LB, ?GET_OBJECT).







-spec
get_objects(lb()) ->
    [] | [object()].
%% @doc
%%      returns all available objects.
%% @end
get_objects(LB) ->
    gen_server:call(LB, ?GET_OBJECTS).





%% ---------------------------------------------------------------------
%% 'proc_lib' callbacks:





%% @hidden
init(Parent, DbgOpts) ->
    init(Parent, DbgOpts, erlang:self()).







%% @hidden
init(Parent, DbgOpts, Name0) ->
    case do_register(Name0) of
        ok ->
            Name = get_name(Name0),
            Dbg = get_debug(Name, DbgOpts),
            proc_lib:init_ack(Parent, {ok, erlang:self()}),
            loop(Parent
                ,Dbg
                ,#?STATE{name = Name
                        ,objects = []
                        ,object = undefined});
        {error, Reason}=Error ->
            proc_lib:init_ack(Parent, Error),
            erlang:exit(Reason)
    end.





%% ---------------------------------------------------------------------
%% 'sys' callbacks:





%% @hidden
system_terminate(Reason, _Parent, Dbg, State) ->
    terminate(Dbg, State, Reason).







%% @hidden
system_continue(Parent, Dbg, State) ->
    loop(Parent, Dbg, State).







%% @hidden
system_get_state(State) ->
    {ok, State}.







%% @hidden
system_replace_state(ReplaceStateFun, State) ->
    NewState = ReplaceStateFun(State),
    {ok, NewState, NewState}.







%% @hidden
system_code_change(State, _Module, _OldVsn, _Extra) ->
    {ok, State}.





%% ---------------------------------------------------------------------
%% Internal functions:





loop(Parent, Dbg, State) ->
    receive
        Msg ->
            process_msg(Parent, Dbg, State, Msg)
    end.







process_msg(Parent
           ,Dbg
           ,#?STATE{name = Name}=State
           ,{?GEN_CAST, {?ONE_FOR_ONE, Msg}=DbgEvent}) ->
    case send(debug(Name, Dbg, DbgEvent)
             ,State
             ,?ONE_FOR_ONE
             ,Msg) of
        {Dbg3, State2, ok} ->
            loop(Parent, Dbg3, State2);
        {Dbg3, State2, {error, Reason}} ->
            terminate(Dbg3, State2, Reason)
    end;

process_msg(Parent
           ,Dbg
           ,#?STATE{name = Name}=State
           ,{?GEN_CAST, {?ONE_FOR_ALL, Msg}=DbgEvent}) ->
    case send(debug(Name, Dbg, DbgEvent)
             ,State
             ,?ONE_FOR_ALL
             ,Msg) of
        {Dbg3, State2, ok} ->
            loop(Parent, Dbg3, State2);
        {Dbg3, State2, {error, Reason}} ->
            terminate(Dbg3, State2, Reason)
    end;

process_msg(Parent
           ,Dbg
           ,#?STATE{name = Name}=State
           ,{?GEN_CALL, From, {?ONE_FOR_ONE, Msg}}) ->
    {Dbg3, State2, Result} = send(debug(Name
                                       ,Dbg
                                       ,{?ONE_FOR_ONE, From, Msg})
                                 ,State
                                 ,?ONE_FOR_ONE
                                 ,Msg),
    Dbg4 = reply(Name, Dbg3, From, Result),
    loop(Parent, Dbg4, State2);

process_msg(Parent
           ,Dbg
           ,#?STATE{name = Name}=State
           ,{?GEN_CALL, From, {?ONE_FOR_ALL, Msg}}) ->
    {Dbg3, State2, Result} = send(debug(Name
                                       ,Dbg
                                       ,{?ONE_FOR_ALL, From, Msg})
                                 ,State
                                 ,?ONE_FOR_ALL
                                 ,Msg),
    Dbg4 = reply(Name, Dbg3, From, Result),
    loop(Parent, Dbg4, State2);

process_msg(Parent
           ,Dbg
           ,#?STATE{name = Name
                   ,objects = Objects
                   ,object = Object}=State
           ,{?GEN_CALL, From, ?GET_OBJECT}) ->
    Dbg2 = debug(Name, Dbg, {?GET_OBJECT, From}),
    case Object of
        undefined ->
            Dbg3 = reply(Name, Dbg2, From, {error, empty}),
            loop(Parent, Dbg3, State);
        Object ->
            Dbg3 = reply(Name, Dbg2, From, {ok, Object}),
            loop(Parent
                ,Dbg3
                ,State#?STATE{object = next_member(Object, Objects)})
    end;

process_msg(Parent
           ,Dbg
           ,#?STATE{name = Name, objects = Objects}=State
           ,{?GEN_CALL, From, ?GET_OBJECTS}) ->
    Dbg2 = reply(Name
                ,debug(Name, Dbg, {?GET_OBJECTS, From})
                ,From
                ,Objects),
    loop(Parent, Dbg2, State);

process_msg(Parent
           ,Dbg
           ,#?STATE{name = Name}=State
           ,{?GEN_CALL, From, {?SUBSCRIBE, Pid}}) ->
    Dbg2 = debug(Name, Dbg, {?SUBSCRIBE, From, Pid}),
    {State2, Result} = do_subscribe(State, Pid),
    Dbg3 = reply(Name, Dbg2, From, Result),
    loop(Parent, Dbg3, State2);

process_msg(Parent
           ,Dbg
           ,#?STATE{name = Name}=State
           ,{?GEN_CALL, From, {?UNSUBSCRIBE, Pid}}) ->
    Dbg2 = debug(Name, Dbg, {?UNSUBSCRIBE, From, Pid}),
    {State2, Result} = do_unsubscribe(State, Pid),
    Dbg3 = reply(Name, Dbg2, From, Result),
    loop(Parent, Dbg3, State2);

process_msg(Parent, Dbg, State, {'EXIT', Parent, Reason}) ->
    terminate(Dbg, State, Reason);

process_msg(Parent
           ,Dbg
           ,#?STATE{name = Name}=State
           ,{'DOWN', _Ref, process, Obj, Reason}) ->
    Dbg2 = debug(Name, Dbg, {down, Obj, Reason}),
    {State2, _Result} = do_unsubscribe(State, Obj),
    loop(Parent, Dbg2, State2);

process_msg(Parent, Dbg, State, {system, From, Msg}) ->
    sys:handle_system_msg(Msg, From, Parent, ?MODULE, Dbg, State);

process_msg(Parent, Dbg, #?STATE{name = Name}=State, Msg) ->
    Dbg2 = debug(Name, Dbg, Msg),
    error_logger:error_msg("lb \"~p\" received unexpected message: \"~p"
                           "\"~n"
                          ,[Name, Msg]),
    loop(Parent, Dbg2, State).







do_register(Name) when erlang:is_atom(Name) ->
    do_register({local, Name});
do_register({local, Name} = Arg) ->
    try erlang:register(Name, self()) of
        true ->
            ok
    catch
        _Type:_Reason ->
            {error, erlang:whereis(Arg)}
    end;
do_register({global, Name} = Arg) ->
    case catch global:register_name(Name, self()) of
        yes ->
            ok;
        no ->
            {error, global:whereis_name(Arg)};
        {'EXIT', Reason} ->
            {error, Reason}
    end;
do_register({via, Module, Name} = Arg) ->
    case catch Module:register_name(Name, self()) of
        yes ->
            ok;
        no ->
            {error, Module:whereis_name(Arg)};
        {'EXIT', Reason} ->
            {error, Reason}
    end;
do_register(_Other) ->
    ok.







get_name({local,Name}) ->
    Name;
get_name({global,Name}) ->
    Name;
get_name({via,_, Name}) ->
    Name;
get_name(Pid) ->
    Pid.







get_debug(Name, DbgOpts) ->
    try
        sys:debug_options(DbgOpts)
    catch
        _Type:_Reason ->
            error_logger:format(
                "~p: ignoring erroneous debug options - ~p~n",
                [Name,DbgOpts]),
            []
    end.







debug(_Name, [], _Event) ->
    [];
debug(Name,  Dbg, Event) ->
    sys:handle_debug(Dbg, fun print/3, Name, Event).







print(IODev, {Type, Msg}, Name) when Type =:= ?ONE_FOR_ONE orelse
                                     Type =:= ?ONE_FOR_ALL ->
    io:format(IODev
             ,"*DBG* lb \"~p\" got asynchronous \"~p\" message \"~p\"~n"
             ,[Name, Type, Msg]);



print(IODev
     ,{Type, {Pid, Tag}, Msg}
     ,Name) when Type =:= ?ONE_FOR_ONE orelse
                 Type =:= ?ONE_FOR_ALL ->
    io:format(IODev
             ,"*DBG* lb \"~p\" got synchronous \"~p\" message \"~p\" fr"
              "om \"~p\" with tag \"~p\" ~n"
             ,[Name, Type, Msg, Pid, Tag]);

print(IODev, {sent, Obj, Msg}, Name) ->
    io:format(IODev
             ,"*DBG* lb \"~p\" sent message \"~p\" to \"~p\" ~n"
             ,[Name, Msg, Obj]);

print(IODev, {?GET_OBJECT, {Pid, Tag}}, Name) ->
    io:format(IODev
             ,"*DBG* lb \"~p\" got request for getting one object from "
              "\"~p\" with tag \"~p\" ~n"
             ,[Name, Pid, Tag]);

print(IODev, {?GET_OBJECTS, {Pid, Tag}}, Name) ->
    io:format(IODev
             ,"*DBG* lb \"~p\" got request for getting all objects from"
              " \"~p\" with tag \"~p\" ~n"
             ,[Name, Pid, Tag]);

print(IODev
     ,{Type, {Pid, Tag}, Pid2}
     ,Name) when Type =:= ?SUBSCRIBE orelse
                 Type =:= ?UNSUBSCRIBE ->
    io:format(IODev
             ,"*DBG* lb \"~p\" got ~p for \"~p\" from \"~p\" wit"
        "h tag \"~p\"~n"
             ,[Name, Type, Pid2, Pid, Tag]);

print(IODev, {down, Obj, Reason}, Name) ->
    io:format(IODev
             ,"*DBG* lb \"~p\" got 'DOWN' message for \"~p\" with reaso"
              "n \"~p\" ~n"
             ,[Name, Obj, Reason]);

print(IODev, {out, {Pid, Tag}, Msg}, Name) ->
    io:format(IODev
             ,"*DBG* lb \"~p\" sent reply \"~p\" to \"~p\" with tag \"~"
              "p\" ~n"
             ,[Name, Msg, Pid, Tag]);

print(IODev, Other, Name) ->
    io:format(IODev
             ,"*DBG* lb \"~p\" got event \"~p\" ~n"
             ,[Name, Other]).







send(Dbg, #?STATE{objects = []}=State, SendType, Msg) ->
    {Dbg, State, {error, {empty, [{send_type, SendType}
                                 ,{message, Msg}]}}};

send(Dbg
    ,#?STATE{objects = Objects, object = Object, name = Name}=State
    ,?ONE_FOR_ONE
    ,Msg) ->
    Dbg2 = do_send(Name, Dbg, Object, Msg),
    {Dbg2, State#?STATE{object = next_member(Object, Objects)}, ok};

send(Dbg
    ,#?STATE{objects = Objects, name = Name}=State
    ,?ONE_FOR_ALL
    ,Msg) ->
    Dbg2 = do_send(Name, Dbg, Objects, Msg),
    {Dbg2, State, ok};

send(_Dbg, _State, Other, Msg) ->
    {error, {unknown_send_type, [{send_type, Other}
                                ,{message, Msg}]}}.







do_send(Name, Dbg, [Object|Objects], Msg) ->
    do_send(Name, do_send(Name, Dbg, Object, Msg), Objects, Msg);
do_send(_Name, Dbg, [], _Msg) ->
    Dbg;
do_send(Name, Dbg, Object, Msg) ->
    catch Object ! Msg,
    debug(Name, Dbg, {sent, Object, Msg}).







next_member(Elem, [Head|_List]=List) ->
    next_member(Elem, Head, List).







next_member(Elem, _Head, [Elem,Elem2|_List]) ->
    Elem2;
next_member(Elem, Head, [_Elem2|List]) ->
    next_member(Elem, Head, List);
next_member(_Elem, Head, []) ->
    Head.







reply(Name, Dbg, {Pid, Tag}=From, Msg) ->
    catch Pid ! {Tag, Msg},
    debug(Name, Dbg, {out, From, Msg}).







do_subscribe(#?STATE{objects = []}=State, Object) ->
    do_monitor(Object),
    {State#?STATE{objects = [Object], object = Object}, ok};
do_subscribe(#?STATE{objects = Objects}=State, Object) ->
    do_monitor(Object),
    {State#?STATE{objects = [Object|Objects]}, ok}.







do_monitor(Object) when erlang:is_pid(Object) ->
    erlang:monitor(process, Object);
do_monitor(Object) when erlang:is_port(Object) ->
    erlang:monitor(port, Object).







do_unsubscribe(#?STATE{objects = [Object]}=State, Object) ->
    {State#?STATE{objects = [], object = undefined}, ok};
do_unsubscribe(#?STATE{objects = Objects, object =Object}=State, Object) ->
    {State#?STATE{objects = lists:delete(Object, Objects)
                 ,object = next_member(Object, Objects)}
    ,ok};
do_unsubscribe(#?STATE{objects = Objects}=State, Object2) ->
    case lists:member(Object2, Objects) of
        true ->
            {State#?STATE{objects = lists:delete(Object2, Objects)}
            ,ok};
        false ->
            {State, {error, {not_found, [{object, Object2}]}}}
    end.







terminate(Dbg, #?STATE{name = Name}=State, Reason) ->
    error_logger:format("** lb \"~p\" terminating \n** Reason for"
    " termination == \"~p\"~n** State == \"~p\"~n"
                       ,[Name
                        ,Reason
                        ,State]),
    sys:print_log(Dbg),
    erlang:exit(Reason).







get_options(Opts) ->
    get_options(Opts, [{debug, ?DEFAULT_DEBUG_OPTIONS}
                      ,{timeout, ?DEFAULT_TIMEOUT}
                      ,{spawn_opts, ?DEFAULT_SPAWN_OPTIONS}], []).







get_options(Opts, [{Key, Default}|Keys], Values) ->
    case lists:keyfind(Key, 1, Opts) of
        {Key, Value} ->
            get_options(Opts, Keys, [Value|Values]);
        _Other ->
            get_options(Opts, Keys, [Default|Values])
    end;
get_options(_Opts, [], Values) ->
    erlang:list_to_tuple(lists:reverse(Values)).
