defmodule ShopifyAPI.ServerBehaviour do
  @moduledoc false

  @callback all() :: list()
  @callback count() :: integer()
  @callback set(struct()) :: :ok
  @callback get(String.t()) :: {:ok, struct()} | {:error, String.t()}
  @callback get(String.t(), String.t()) :: {:ok, struct()} | {:error, String.t()}
  @callback drop(String.t(), String.t()) :: {:ok, true}
  @callback drop(String.t()) :: {:ok, true}
  @callback drop!(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  @callback drop!(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  @callback drop_all() :: :ok

  @optional_callbacks get: 2, get: 1, drop: 2, drop: 1, drop!: 2, drop!: 1

end
