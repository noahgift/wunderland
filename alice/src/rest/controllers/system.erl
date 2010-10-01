-module (system).
-export ([get/1, post/2, put/2, delete/2]).

% Get system data
get([]) ->   
  {ok, UsedMemory}    	= get_used_memory(),
  {ok, PercentMemory} 	= get_percent_memory(),
  {ok, Messages}      	= get_message_count(),
  {ok, SysMemory}     	= get_memory_count(),
  {ok, Consumers}     	= get_consumers_count(),
  {ok, UnAck}         	= get_messages_unacknowledged_count(),
  {ok, ErlangInfo}	  	= get_erlang_system_info(),
  {ok, OsVersionNum}	= get_os_version(),
  {ok, HostName}		= get_host_name(),
  {ok, UpTime}		= get_uptime(),
  Out = {struct,
    [            
      {system_memory, UsedMemory},
      {percent_memory, PercentMemory},
      {total_queue_memory, SysMemory},
      {consumers, Consumers},
      {messages_unacknowledged, UnAck},
      {total_messages, Messages},
	  {erlang_info, ErlangInfo},
	  {os_version, OsVersionNum},
	  {get_host_name, HostName},
	  {get_up_time, UpTime}
    ]
  },  
  
  {?MODULE, Out};
  
get(_Path) -> {"error", <<"unhandled">>}.

post(_Path, _Data) -> {"error", <<"unhandled">>}.

put(_Path, _Data) -> {"error", <<"unhandled">>}.

delete(_Path, _Data) -> {"error", <<"unhandled">>}.

%%====================================================================
%% MEMORY
%%====================================================================

%%--------------------------------------------------------------------
%% Function: get_percent_memory () -> {ok, PercentMemory}
%% Description: Get the percentage of the total memory available
%%--------------------------------------------------------------------

% Uptime of erlang itself
get_uptime() ->
	RHost = rabint:rabbit_node(),
	{NUptime,_} = rpc:call(RHost, erlang, statistics,[wall_clock]),
	Uptime = NUptime div 1000,
	{ok, Uptime}.

% Get Hostname
get_host_name() ->
	Host = os:getenv("HOSTNAME"),
	FullHostName = list_to_binary(Host),
	{ok, FullHostName}.


%% Grabs Operating System Type
%% This is a bit brittle as it assumes this is running on *nix
get_os_version() ->
	OSVer = os:cmd("uname"),
 	OSVersion = erlang:list_to_binary(OSVer),
	{ok, OSVersion}.

%% Gets useful information about erlang and the core os
get_erlang_system_info() ->
	%% 	SystemArchitecture = erlang:system_info(system_architecture_),
	ErlVer = erlang:system_info(otp_release),
	ErlangVersion = erlang:list_to_binary(ErlVer),
	{ok, ErlangVersion}.

get_percent_memory() ->
  MemoryList  = memsup:get_system_memory_data(),
  TotalMem    = proplists:get_value(total_memory, MemoryList),
  FreeMem     = proplists:get_value(free_memory, MemoryList),
  Tot         = (FreeMem/TotalMem)*100,
  [Perc|_]    = io_lib:fwrite("~.2f", [Tot]),
  {ok, erlang:list_to_float(Perc)}.	

get_used_memory() ->
  MemoryList  = memsup:get_system_memory_data(),
  TotalMem    = proplists:get_value(total_memory, MemoryList),
  FreeMem     = proplists:get_value(free_memory, MemoryList),
  {ok, TotalMem - FreeMem}.

get_message_count() -> {ok, aggregate_vhosts(fun(Data, Sum) -> proplists:get_value(messages, Data) + Sum end, 0)}.
get_consumers_count() -> {ok, aggregate_vhosts(fun(Data, Sum) -> proplists:get_value(consumers, Data) + Sum end, 0)}.
get_messages_unacknowledged_count() -> {ok, aggregate_vhosts(fun(Data, Sum) -> proplists:get_value(messages_unacknowledged, Data) + Sum end, 0)}.
get_memory_count() -> {ok, aggregate_vhosts(fun(Data, Sum) -> proplists:get_value(memory, Data) + Sum end, 0)}.

aggregate_vhosts(Fun, Acc) ->
  {_, VhostListing} = vhosts:get([]),
  
  VhostList = [ erlang:binary_to_list(V) || V <- VhostListing ],
  NumArr = lists:map(
    fun(Vhost) -> 
      % Fetch the queues for this vhost
      case queues:get_info_for(Vhost, [name, memory, messages, consumers, messages_unacknowledged]) of
        []  -> 0;
        E   -> lists:foldl(Fun, Acc, E)
      end
    end, VhostList),
  lists:foldl(fun(X, S) -> X + S end, 0, NumArr).
    