-module(helga).
-behaviour(gen_statem).

-include_lib("eunit/include/eunit.hrl").

-export([start/3,get_status/1,stop/1]).
-export([terminate/3,code_change/4,init/1,callback_mode/0]).
-export([successed/3,failed/3]).

-record(data, {checker,
               callback
              }).

%% API.  This example uses a registered name
%% and does not link to the caller.
start(Name, Checker, Callback) ->
    gen_statem:start({local,Name}, ?MODULE, [Checker, Callback], []).
get_status(Name) ->
    gen_statem:call(Name, get_status).
stop(Name) ->
    gen_statem:stop(Name).

%% data [checker_func, callback_func, status, retries, timeout?]
%% state successed, failed

%% Mandatory callback functions
terminate(_Reason, _State, _Data) ->
    void.
code_change(_Vsn, State, Data, _Extra) ->
    {ok,State,Data}.
init([Checker, Callback]) ->
    Data = #data{checker=Checker, callback=Callback},
    %% Set the initial state + data.  Data is used only as a counter.
    State = successed,
    {ok,State,Data}.
callback_mode() -> state_functions.

%%% state callback(s)

successed(enter, OldState, Data) ->
    io:format("enter, ~p, ~p ~n", [OldState, Data]),
    {keep_state, Data, [{state_timeout,10000,retry}]};
successed(state_timeout, retry, #data{checker = Check} = Data) ->
    io:format("timeout, ~p, ~n", [Data]),
    case Check() of
        ok ->
            {keep_state, Data, [state_timeout,10000,retry]};
        {error, Error} ->
            {next_state, failed, Data, [state_timeout,10000,retry]}
    end;
successed(EventType, EventContent, Data) ->
    handle_event(EventType, EventContent, Data).

failed(enter, OldState, Data) ->
    io:format("enter, ~p, ~p ~n", [OldState, Data]),
    {keep_state, Data, [{state_timeout,10000,retry}]};
failed(state_timeout, retry, #data{checker = Check} = Data) ->
    io:format("timeout, ~p, ~n", [Data]),
    case Check() of
        ok ->
            {next_state, successed, Data, [state_timeout,10000,retry]};
        {error, Error} ->
            {keep_state, Data, [state_timeout,10000,retry]}
    end;
failed(EventType, EventContent, Data) ->
    handle_event(EventType, EventContent, Data).

%% Handle events common to all states
handle_event({call,From}, get_status, Data) ->
    %% Reply with the current count
    {keep_state,Data,[{reply,From,Data}]};
handle_event(_, _, Data) ->
    %% Ignore all other events
    {keep_state,Data}.
