%%%-------------------------------------------------------------------
%%% @author Edouard Swiac <edouard@2600hz.org>
%%% @copyright (C) 2011, VoIP INC
%%% @doc
%%% Handle AMQP requests to write system configuration data.
%%% Support nested keys like key#subkey#subsubkey
%%% @end
%%%-------------------------------------------------------------------
-module(sysconf_set).

-export([init/0, handle_req/2]).

-include("sysconf.hrl").

init() ->
    ok.

-spec handle_req/2 :: (wh_json:json_object(), proplist()) -> 'ok'.
handle_req(ApiJObj, _Props) ->
    ?LOG_START("received sysconf set"),
    true = wapi_sysconf:set_req_v(ApiJObj),
    
    Category = wh_json:get_value(<<"Category">>, ApiJObj),
    Key = wh_json:get_value(<<"Key">>, ApiJObj),
    Value = wh_json:get_value(<<"Value">>, ApiJObj),

    {ok, _} = whapps_config:set(Category, Key, Value, wh_json:get_value(<<"Node">>, ApiJObj)),

    RespQ =  wh_json:get_value(<<"Server-ID">>, ApiJObj),

    Resp = [{<<"Category">>, Category} 
            ,{<<"Key">>, Key}
            ,{<<"Value">>, Value}
            | wh_api:default_headers(?APP_NAME, ?APP_VERSION)
           ],
    wapi_sysconf:publish_write_resp(RespQ, Resp).
