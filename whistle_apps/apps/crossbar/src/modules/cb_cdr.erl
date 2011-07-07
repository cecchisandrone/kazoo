%%%-------------------------------------------------------------------
%%% @author Edouard Swiac <edouard@2600hz.org>
%%% @copyright (C) 2011, VoIP INC
%%% @doc
%%%
%%% CDR
%%% Read only access to CDR docs
%%%
%%% @end
%%% Created : 30 Jun 2011 Edouard Swiac <edouard@2600hz.org>
%%%-------------------------------------------------------------------
-module(cb_cdr).

-behaviour(gen_server).

%% API
-export([start_link/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

-include("../../include/crossbar.hrl").
-include_lib("webmachine/include/webmachine.hrl").

-define(SERVER, ?MODULE).

-define(VIEW_FILE, <<"views/cdr.json">>).
-define(CB_LIST, {<<"cdr">>, <<"crossbar_listing">>}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init(_) ->
    {ok, ok, 0}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call(_Request, _From, State) ->
    {reply, ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info({binding_fired, Pid, <<"v1_resource.allowed_methods.cdr">>, Payload}, State) ->
    spawn(fun() ->
		  {Result, Payload1} = allowed_methods(Payload),
                  Pid ! {binding_result, Result, Payload1}
	  end),
    {noreply, State};

handle_info({binding_fired, Pid, <<"v1_resource.resource_exists.cdr">>, Payload}, State) ->
    spawn(fun() ->
		  {Result, Payload1} = resource_exists(Payload),
                  Pid ! {binding_result, Result, Payload1}
	  end),
    {noreply, State};

handle_info({binding_fired, Pid, <<"v1_resource.validate.cdr">>, [RD, Context | Params]}, State) ->
    spawn(fun() ->
		  Context1 = validate(Params, RD, Context),
		  Pid ! {binding_result, true, [RD, Context1, Params]}
	  end),
    {noreply, State};

handle_info({binding_fired, Pid, <<"v1_resource.execute.get.cdr">>, [RD, Context | Params]}, State) ->
    spawn(fun() ->
		  Pid ! {binding_result, true, [RD, Context, Params]}
	  end),
    {noreply, State};

handle_info({binding_fired, Pid, <<"account.created">>, _Payload}, State) ->
    Pid ! {binding_result, true, ?VIEW_FILE},
    {noreply, State};

handle_info({binding_fired, Pid, _B, Payload}, State) ->
    Pid ! {binding_result, false, Payload},
    {noreply, State};

handle_info(timeout, State) ->
    bind_to_crossbar(),
    whapps_util:update_all_accounts(?VIEW_FILE),
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function binds this server to the crossbar bindings server,
%% for the keys we need to consume.
%% @end
%%--------------------------------------------------------------------
-spec(bind_to_crossbar/0 :: () ->  no_return()).
bind_to_crossbar() ->
    _ = crossbar_bindings:bind(<<"v1_resource.allowed_methods.cdr">>),
    _ = crossbar_bindings:bind(<<"v1_resource.resource_exists.cdr">>),
    _ = crossbar_bindings:bind(<<"v1_resource.validate.cdr">>),
    _ = crossbar_bindings:bind(<<"v1_resource.execute.get.cdr">>),
    crossbar_bindings:bind(<<"account.created">>).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function determines the verbs that are appropriate for the
%% given Nouns.  IE: '/cdr/' can only accept GET
%%
%% Failure here returns 405
%% @end
%%--------------------------------------------------------------------
-spec(allowed_methods/1 :: (Paths :: list()) -> tuple(boolean(), http_methods())).
allowed_methods([]) ->
    {true, ['GET']};
allowed_methods([_]) ->
    {true, ['GET']};
allowed_methods(_) ->
    {false, []}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function determines if the provided list of Nouns are valid.
%%
%% Failure here returns 404
%% @end
%%--------------------------------------------------------------------
-spec(resource_exists/1 :: (Paths :: list()) -> tuple(boolean(), [])).
resource_exists([]) ->
    {true, []};
resource_exists([_]) ->
    {true, []};
resource_exists(_) ->
    {false, []}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function determines if the parameters and content are correct
%% for this request
%%
%% Failure here returns 400
%% @end
%%--------------------------------------------------------------------
-spec(validate/3 :: (Params :: list(), RD :: #wm_reqdata{}, Context :: #cb_context{}) -> #cb_context{}).
validate([], #wm_reqdata{req_qs=QueryString}, #cb_context{req_verb = <<"get">>}=Context) ->
    load_cdr_summary(Context, QueryString);
validate([CDRId], _, #cb_context{req_verb = <<"get">>}=Context) ->
    load_cdr(CDRId, Context);
validate(_, _, Context) ->
    crossbar_util:response_faulty_request(Context).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Normalizes the resuts of a view
%% @end
%%--------------------------------------------------------------------
-spec(normalize_view_results/2 :: (JObj :: json_object(), Acc :: json_objects()) -> json_objects()).
normalize_view_results(JObj, Acc) ->
    [wh_json:get_value(<<"value">>, JObj)|Acc].

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Attempt to load list of CDR, each summarized.
%% @end
%%--------------------------------------------------------------------
-spec(load_cdr_summary/2 :: (Context :: #cb_context{}, QueryString :: list()) -> #cb_context{}).
load_cdr_summary(#cb_context{db_name=DbName}=Context, QueryString) ->
    case QueryString of
        [_|_] -> case do_filter(DbName, QueryString, []) of
                     [_|_]=DocIds -> crossbar_doc:load_view(?CB_LIST, [{<<"keys">>, DocIds}], Context, fun normalize_view_results/2);
                     _ -> crossbar_util:response_faulty_request(Context)

                 end;
        _ -> crossbar_doc:load_view(?CB_LIST, [], Context, fun normalize_view_results/2)
    end.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Attempt to load list of Doc ID from the crossbar_listing view,
%% filtered on the query string params
%% @end
%%--------------------------------------------------------------------
-spec(do_filter/3 :: (DbName :: binary(), QueryString :: list(tuple(string(), term())), Options :: list()) -> list(binary())).
do_filter(DbName, QueryString, _Options) ->
    QueryStringBinary = [{list_to_binary(K), list_to_binary(V)} || {K, V} <- QueryString],
    ValidParams = lists:foldl(fun({<<"filter_", Param/binary>>, V}, Acc) -> [{Param, V} | Acc]; (_, Acc) -> Acc end, [], QueryStringBinary),

    {ok, AllDocs} = couch_mgr:get_results(DbName, ?CB_LIST, [{<<"include_docs">>, true}]),
    UnfilteredDocs = [wh_json:get_value(<<"doc">>, Doc, ?EMPTY_JSON_OBJECT) || Doc <- AllDocs],
    filter_docs(UnfilteredDocs, ValidParams).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Return the Doc IDs for which all the parameters have the requested value
%% @end
%%--------------------------------------------------------------------
-spec(filter_docs/2 :: (Docs :: json_objects(), Props :: list(tuple(binary(), binary()))) -> list(binary())).
filter_docs(Docs, Props) ->
    [wh_json:get_value(<<"_id">>, Doc) || Doc <- Docs, lists:all(fun({Key,Val}) -> wh_json:get_value(Key, Doc) =:= Val end, Props)].


build_filter_options(<<"filter_", Param/binary>>) ->
    ok;
build_filter_options(<<"created_from">>) ->
    ok;
build_filter_options(<<"created_to">>) ->
    ok;
build_filter_options(<<"modified_from">>) ->
    ok;
build_filter_options(<<"modified_to">>) ->
    ok.
%% build_filter_options(<<"range_", Param/binary, "_from">>) -> nyi.
%% build_filter_options(<<"range_", Param/binary, "_to">>) -> nyi.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Load a CDR document from the database
%% @end
%%--------------------------------------------------------------------
-spec(load_cdr/2 :: (DocId :: binary(), Context :: #cb_context{}) -> #cb_context{}).
load_cdr(CdrId, Context) ->
    crossbar_doc:load(CdrId, Context).
