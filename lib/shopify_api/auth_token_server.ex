defmodule ShopifyAPI.AuthTokenServer do
  use GenServer
  require Logger

  @name :shopify_api_auth_token_server

  def start_link(_opts) do
    Logger.info(fn -> "Starting #{__MODULE__} ..." end)

    p = GenServer.start_link(__MODULE__, %{}, name: @name)
    call_initializer(auth_token_server_config(:initializer))
    p
  end

  def all do
    GenServer.call(@name, :all)
  end

  def get(shop, app) do
    GenServer.call(@name, {:get, create_key(shop, app)})
  end

  def get_for_app(app) do
    GenServer.call(@name, {:get_for_app, app})
  end

  @spec count :: integer
  def count do
    GenServer.call(@name, :count)
  end

  def set(shop, app, new_values, call_persist \\ true) do
    token = Map.merge(%{app_name: app, shop_name: shop}, new_values)

    if call_persist do
      Task.start(fn ->
        __MODULE__.persist(auth_token_server_config(:persistance), create_key(shop, app), token)
      end)
    end

    GenServer.cast(@name, {:set, create_key(shop, app), token})
  end

  defp create_key(shop, app) do
    "#{shop}:#{app}"
  end

  def auth_token_server_config(key) do
    Application.get_env(:shopify_api, ShopifyAPI.AuthTokenServer)[key]
  end

  def call_initializer(fun) when is_function(fun), do: fun.()
  def call_initializer(_), do: %{}
  def persist(fun, key, value) when is_function(fun), do: fun.(key, value)
  def persist(_, _, _), do: nil

  #
  # Callbacks
  #

  def init(state), do: {:ok, state}

  @callback handle_cast(map, map) :: tuple
  def handle_cast({:set, key, new_values}, %{} = state) do
    new_state =
      update_in(state, [key], fn t ->
        case t do
          nil -> Map.merge(%ShopifyAPI.AuthToken{}, new_values)
          _ -> Map.merge(t, new_values)
        end
      end)

    {:noreply, new_state}
  end

  def handle_call(:all, _caller, state) do
    {:reply, state, state}
  end

  def handle_call({:get, key}, _caller, state) do
    {:reply, Map.fetch(state, key), state}
  end

  def handle_call({:get_for_app, app}, _caller, state) do
    vals =
      state
      |> Map.values()
      |> Enum.filter(fn t -> t.app_name == app end)

    {:reply, vals, state}
  end

  def handle_call(:count, _caller, state) do
    {:reply, Enum.count(state), state}
  end
end
