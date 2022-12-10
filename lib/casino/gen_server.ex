defmodule Casino.GenServer do
  alias Plug.CSRFProtection.InvalidCrossOriginRequestError
  defmacro __using__(_opts) do
    quote do
      use GenServer
      import unquote(__MODULE__)
    end
  end

  def ok(state, timeout \\ nil)

  def ok(state, timeout_fn) when is_function(timeout_fn),
    do: reply(:ok, state, timeout_fn.(state))

  def ok(state, timeout), do: reply(:ok, state, timeout)

  def no_reply(state, timeout \\ nil)

  def no_reply(state, timeout_fn) when is_function(timeout_fn),
    do: {:noreply, state, timeout_fn.(state)}

  def no_reply(state, nil), do: {:noreply, state}
  def no_reply(state, timeout), do: {:noreply, state, timeout}

  defmacro nr_and_queue_message(state, message, timeout) do
    quote bind_quoted: [state: state, message: message, timeout: timeout] do
      Process.send_after(__MODULE__, message, timeout)
      no_reply(state)
    end
  end

  def reply(response, state, timeout \\ nil)
  def reply(response, state, nil), do: {:reply, response, state}
  def reply(response, state, timeout), do: {:reply, response, state, timeout}

  def stop_normal(response, state), do: {:stop, :normal, response, state}

  def seconds(seconds), do: seconds * 1000

end
