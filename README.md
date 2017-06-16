# Load-Balancer
Porcess for spreading Erlang messages to Erlang process(es) or port(s).


# Download
```sh
~ $ git clone https://github.com/Pouriya-Jahanbakhsh/lb.git
```

# Compile
```sh
~ $ cd lb
```

#### rebar
```sh 
~/lb $ rebar compile
==> lb (compile)
Compiled src/lb.erl
```

#### rebar3
```sh
~/lb $ rebar3 compile
===> Verifying dependencies...
===> Compiling lb
```


# How to use?
If you need a real example, I reccomend to see [**this post**](http://codefather.org/posts/Using_Erlang_process_Load-Balancer_(example).html).  
You need to start a **Load-Balancer** and your process which wants to receive Erlang messages from **Load-Balancer** should subscribe to **Load-Balancer**:

```erlang
Erlang/OTP 19 [erts-8.3] [source-d5c06c6] [64-bit] [smp:8:8] [async-threads:0] [hipe] [kernel-poll:false]

Eshell V8.3  (abort with ^G)
%% you can use start_link/1 & start_link/2, read the doc
1> {ok, LB} = lb:start_link().
{ok,<0.106.0>}

%% subscribe caller (self()) for receiving messages.
2> lb:subscribe(LB).
ok

%% subscribe self twic
3> lb:subscribe(LB, erlang:self()).
ok

%% one of subscribers will receive message foo, request is synchronous.
4> lb:send_sync(LB, foo, one_for_one).
ok

5> flush().
Shell got foo
ok

%% next subscriber will receive message "bar", request is asynchronous.
6> lb:send_async(LB, "bar", one_for_one).
ok

7> flush().
Shell got "bar"
ok

%% all subscribers will receive message <<"baz">>.
8> lb:send_sync(LB, <<"baz">>, one_for_all).
ok
 
9> flush().
Shell got <<"baz">>
Shell got <<"baz">>
ok

%% fetching all available subscribers.
%% You can use lb:get_object(LB) for fetching one subscriber, in next call you will get next subscriber and so on.
10> lb:get_objects(LB). 
[<0.103.0>,<0.103.0>]

%% unsubscribe caller (self())
11> lb:unsubscribe(LB).
ok

12> lb:get_objects(LB).
[<0.103.0>]

%% unsubscribe specific pid or port
15> lb:unsubscribe(LB, erlang:self()).
ok

16> lb:get_object(LB).                
{error,empty}

17> lb:send_sync(LB, oops, one_for_one).
{error,{empty,[{send_type,one_for_one},{message,oops}]}}
```

## Debugging
```erl
Erlang/OTP 19 [erts-8.3] [source-d5c06c6] [64-bit] [smp:8:8] [async-threads:0] [hipe] [kernel-poll:false]

Eshell V8.3  (abort with ^G)

1> lb:start_link({local, load_balancer}, [{debug, [trace]}]).
{ok,<0.105.0>}

2> lb:subscribe(load_balancer).
*DBG* lb "load_balancer" got subscribe for "<0.102.0>" from "<0.102.0>" with tag "#Ref<0.0.3.875>"
*DBG* lb "load_balancer" sent reply "ok" to "<0.102.0>" with tag "#Ref<0.0.3.875>" 
ok

3> lb:send_sync(load_balancer, hello, one_for_one).
*DBG* lb "load_balancer" got synchronous "one_for_one" message "hello" from "<0.102.0>" with tag "#Ref<0.0.3.883>" 
*DBG* lb "load_balancer" sent message "hello" to "<0.102.0>" 
*DBG* lb "load_balancer" sent reply "ok" to "<0.102.0>" with tag "#Ref<0.0.3.883>" 
ok

4> lb:subscribe(load_balancer).                    
*DBG* lb "load_balancer" got subscribe for "<0.102.0>" from "<0.102.0>" with tag "#Ref<0.0.3.891>"
*DBG* lb "load_balancer" sent reply "ok" to "<0.102.0>" with tag "#Ref<0.0.3.891>" 
ok

5> lb:send_sync(load_balancer, hi, one_for_all).   
*DBG* lb "load_balancer" got synchronous "one_for_all" message "hi" from "<0.102.0>" with tag "#Ref<0.0.3.898>" 
*DBG* lb "load_balancer" sent message "hi" to "<0.102.0>" 
*DBG* lb "load_balancer" sent message "hi" to "<0.102.0>" 
*DBG* lb "load_balancer" sent reply "ok" to "<0.102.0>" with tag "#Ref<0.0.3.898>" 
ok

6> lb:get_object(load_balancer).                
*DBG* lb "load_balancer" got request for getting one object from "<0.102.0>" with tag "#Ref<0.0.3.907>" 
*DBG* lb "load_balancer" sent reply "{ok,<0.102.0>}" to "<0.102.0>" with tag "#Ref<0.0.3.907>" 
{ok,<0.102.0>}

7> lb:get_objects(load_balancer).
*DBG* lb "load_balancer" got request for getting all objects from "<0.102.0>" with tag "#Ref<0.0.3.914>" 
*DBG* lb "load_balancer" sent reply "[<0.102.0>,<0.102.0>]" to "<0.102.0>" with tag "#Ref<0.0.3.914>" 
[<0.102.0>,<0.102.0>]

8> lb:unsubscribe(load_balancer).
*DBG* lb "load_balancer" got unsubscribe for "<0.102.0>" from "<0.102.0>" with tag "#Ref<0.0.3.921>"
*DBG* lb "load_balancer" sent reply "ok" to "<0.102.0>" with tag "#Ref<0.0.3.921>" 
ok
```


## License
BSD 3-Clause

## Links
[**Github**](https://github.com/Pouriya-Jahanbakhsh/lb)  
This documentation is availible in [http://docs.codefather.org/lb](http://docs.codefather.org/lb) too.
