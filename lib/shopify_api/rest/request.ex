defmodule ShopifyAPI.REST.Request do
  @moduledoc """
  The internal interface to Shopify's REST Admin API, built on HTTPoison.

  Adds support for building URLs and authentication headers from an AuthToken,
  as well as functionality to throttle/log requests and parse responses.
  """

  use HTTPoison.Base
  require Logger

  alias HTTPoison.Error
  alias ShopifyAPI.{AuthToken, CallLimit, JSONSerializer, Throttled}

  @default_api_version "2019-04"

  # Use HTTP in test for Bypass, HTTPS in all other environments
  @transport if Mix.env() == :test, do: "http://", else: "https://"

  @http_receive_timeout Application.get_env(:shopify_api, :http_timeout)

  ## Public Interface

  def perform(%AuthToken{} = token, method, path, body \\ "", params \\ []) do
    url = add_params_to_url(url(token, path), params)
    headers = headers(token)

    response =
      Throttled.request(
        fn -> logged_request(method, url, body, headers, token: token) end,
        token
      )

    case response do
      {:ok, %{status_code: status} = response} when status >= 200 and status < 300 ->
        # TODO probably have to return the response here if we want to use the headers
        {:ok, fetch_body(response)}

      {:ok, response} ->
        {:error, response}

      {:error, _} = value ->
        value

      response ->
        {:error, response}
    end
  end

  def version do
    Keyword.get(
      Application.get_env(:shopify_api, ShopifyAPI.REST) || [],
      :api_version,
      @default_api_version
    )
  end

  ## HTTPoison Overrides

  def logged_request(method, url, body, headers, options) do
    {time, response} = :timer.tc(&request/5, [method, url, body, headers, options])
    token = Keyword.get(options, :token, %ShopifyAPI.AuthToken{})

    log_request(token, method, url, time, response)
    send_telemetry(token, method, url, time, response)

    response
  end

  @impl true
  def process_request_options(opts) do
    Keyword.put_new(opts, :recv_timeout, @http_receive_timeout)
  end

  @impl true
  def process_response_body(body) do
    JSONSerializer.decode(body)
  end

  ## Private Helpers

  defp send_telemetry(
         %{app_name: app, shop_name: shop} = _token,
         method,
         url,
         time,
         {:ok, %{status_code: status}} = response
       ) do
    :telemetry.execute(
      [:shopify_api, :rest_request, :success],
      %{request_time: time, remaining_calls: remaining_calls(response)},
      %{
        app: app,
        shop: shop,
        url: url,
        status_code: status,
        method: method,
        module: module_name()
      }
    )
  end

  defp send_telemetry(
         %{app_name: app, shop_name: shop} = _token,
         method,
         url,
         time,
         {:error, %Error{reason: reason}} = _response
       ) do
    :telemetry.execute(
      [:shopify_api, :rest_request, :failure],
      %{request_time: time},
      %{
        app: app,
        shop: shop,
        url: url,
        method: method,
        module: module_name(),
        reason: reason
      }
    )
  end

  defp send_telemetry(_token, _method, _url, _time, _response), do: nil

  defp log_request(token, method, url, time, response) do
    Logger.debug(fn ->
      %{app_name: app, shop_name: shop} = token
      module = module_name()
      method = method |> to_string() |> String.upcase()

      "#{module} #{method} #{url} #{app} #{shop} (#{remaining_calls(response)}) [#{
        div(time, 1_000)
      }ms]"
    end)
  end

  defp module_name do
    __MODULE__ |> to_string() |> String.trim_leading("Elixir.")
  end

  defp remaining_calls({:ok, response}) do
    response
    |> CallLimit.limit_header_or_status_code()
    |> CallLimit.get_api_remaining_calls()
  end

  defp remaining_calls(_), do: nil

  defp url(%{shop_name: domain}, path),
    do: "#{@transport}#{domain}/admin/api/#{version()}/#{path}"

  defp headers(%{token: access_token}) do
    [
      {"Content-Type", "application/json"},
      {"X-Shopify-Access-Token", access_token}
    ]
  end

  defp fetch_body(http_response) do
    with {:ok, map_fetched} <- Map.fetch(http_response, :body),
         {:ok, body} <- map_fetched,
         do: body
  end

  @doc """
  Take an existing URI and add additional params, appending and replacing as necessary
  ## Examples
      iex> add_params_to_url("http://example.com/wat", [])
      "http://example.com/wat"
      iex> add_params_to_url("http://example.com/wat", [q: 1])
      "http://example.com/wat?q=1"
      iex> add_params_to_url("http://example.com/wat", [q: 1, t: 2])
      "http://example.com/wat?q=1&t=2"
      iex> add_params_to_url("http://example.com/wat", %{q: 1, t: 2})
      "http://example.com/wat?q=1&t=2"
      iex> add_params_to_url("http://example.com/wat?q=1&t=2", [])
      "http://example.com/wat?q=1&t=2"
      iex> add_params_to_url("http://example.com/wat?q=1", [t: 2])
      "http://example.com/wat?q=1&t=2"
      iex> add_params_to_url("http://example.com/wat?q=1", [q: 3, t: 2])
      "http://example.com/wat?q=3&t=2"
      iex> add_params_to_url("http://example.com/wat?q=1&s=4", [q: 3, t: 2])
      "http://example.com/wat?q=3&s=4&t=2"
      iex> add_params_to_url("http://example.com/wat?q=1&s=4", %{q: 3, t: 2})
      "http://example.com/wat?q=3&s=4&t=2"
  """
  @spec add_params_to_url(binary, list) :: binary
  def add_params_to_url(url, params) do
    url
    |> URI.parse()
    |> merge_uri_params(params)
    |> String.Chars.to_string()
  end

  @spec merge_uri_params(URI.t(), list) :: URI.t()
  defp merge_uri_params(uri, []), do: uri

  defp merge_uri_params(%URI{query: nil} = uri, params) when is_list(params) or is_map(params) do
    Map.put(uri, :query, URI.encode_query(params))
  end

  defp merge_uri_params(%URI{} = uri, params) when is_list(params) or is_map(params) do
    Map.update!(uri, :query, fn q ->
      q
      |> URI.decode_query()
      |> Map.merge(param_list_to_map_with_string_keys(params))
      |> URI.encode_query()
    end)
  end

  @spec param_list_to_map_with_string_keys(list) :: map
  defp param_list_to_map_with_string_keys(list) when is_list(list) or is_map(list) do
    for {key, value} <- list, into: Map.new() do
      {"#{key}", value}
    end
  end
end
