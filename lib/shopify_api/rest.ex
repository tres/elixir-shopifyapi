defmodule ShopifyAPI.REST do
  @moduledoc """
  Provide a hook to bypass using the real REST client with a mock. This utilizes the Mox paradigm
    of defining the underlying library used at runtime by using application configuration.

      In order to use this feature in your tests, configure

    config :shopify_api, ShopifyAPI,
      adapter: MyApp.TestAdapter

      MyApp.TestAdapter must implement the ShopifyAPI.REST.Behaviour

    example:
    defmodule MyApp.TestAdapter do
      alias ShopifyAPI.AuthToken

      @behaviour ShopifyAPI.REST.Behaviour

      def get(%AuthToken{} = token, path, params \\ [], options \\ []) do

      end

      # todo: post, put, delete

    end

  """

  defdelegate get(token, path), to: ShopifyAPI.adapter()
  defdelegate get(token, path, params), to: ShopifyAPI.adapter()
  defdelegate get(token, path, params, options), to: ShopifyAPI.adapter()

  defdelegate post(token, path), to: ShopifyAPI.adapter()
  defdelegate post(token, path, obj), to: ShopifyAPI.adapter()
  defdelegate post(token, path, obj, options), to: ShopifyAPI.adapter()

  defdelegate put(token, path, obj), to: ShopifyAPI.adapter()
  defdelegate put(token, path, obj, options), to: ShopifyAPI.adapter()

  defdelegate delete(token, path), to: ShopifyAPI.adapter()
end
