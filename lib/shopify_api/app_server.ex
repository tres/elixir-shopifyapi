defmodule ShopifyAPI.AppServer do
  @moduledoc "Write-through cache for App structs."

  use GenServer

  alias ShopifyAPI.App
  alias ShopifyAPI.Config

  @behaviour ShopifyAPI.ServerBehaviour

  @table __MODULE__

  @impl true
  @spec all() :: map()
  def all do
    @table
    |> :ets.tab2list()
    |> Map.new()
  end

  @impl true
  @spec count() :: integer()
  def count, do: :ets.info(@table, :size)

  @impl true
  @spec set(App.t(), boolean()) :: :ok
  def set(%App{name: name} = app, persist? \\ true) do
    :ets.insert(@table, {name, app})
    if persist?, do: do_persist(app)
    :ok
  end

  @impl true
  @spec get(String.t()) :: {:ok, App.t()} | {:error, String.t()}
  def get(name) do
    case :ets.lookup(@table, name) do
      [{^name, app}] -> {:ok, app}
      [] -> {:error, "App #{name} not found"}
    end
  end

  @impl true
  @spec drop_all() :: boolean()
  def drop_all do
    :ets.delete_all_objects(@table)
  end

  ## GenServer Callbacks

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(:ok) do
    create_table!()
    for %App{} = app <- do_initialize(), do: set(app, false)
    {:ok, :no_state}
  end

  ## Private Helpers

  defp create_table! do
    :ets.new(@table, [
      :set,
      :public,
      :named_table,
      read_concurrency: true
    ])
  end

  # Calls a configured initializer to obtain a list of Apps.
  defp do_initialize do
    case Config.lookup(__MODULE__, :initializer) do
      {module, function, args} -> apply(module, function, args)
      {module, function} -> apply(module, function, [])
      _ -> []
    end
  end

  # Attempts to persist a App if a persistence callback is configured
  defp do_persist(%App{name: name} = app) do
    case Config.lookup(__MODULE__, :persistence) do
      {module, function, args} -> apply(module, function, [name, app | args])
      {module, function} -> apply(module, function, [name, app])
      _ -> nil
    end
  end
end
