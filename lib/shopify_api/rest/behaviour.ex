defmodule ShopifyAPI.REST.Behaviour do
  @moduledoc """
Behaviour associated with rest calls. Provides the ability to hook up REST calls to client logic
  using the Mox mocking pattern.
"""

  alias ShopifyAPI.AuthToken

  @callback get(AuthToken.t(), path :: String.t(), keyword(), keyword()) ::
            {:ok, %{required(String.t()) => [map()]}} | Enumerable.t()
  @callback post(AuthToken.t(), path :: String.t(), map(), keyword()) :: {:ok, map()}
  @callback put(AuthToken.t(), path :: String.t(), map(), keyword()) :: {:ok, map()}
  @callback delete(AuthToken.t(), path :: String.t()) :: {:ok, map()}

end
