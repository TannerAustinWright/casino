defmodule CasinoWeb.GameChannel do
  use Phoenix.Channel

  require Logger

  def join("game:lobby", _message, socket) do
    Casino.join(socket.assigns.user.id)
    {:ok, socket}
  end

  # broadcast!(socket, "out_server_socket", params)
  def handle_in("place_bet", %{"ready" => _ready, "wager" => _wager}, socket) do
    # user_id = socket.assigns.user.id
    # Casino.place_bet(user_id, wager, ready)
    {:noreply, socket}
  end

  def handle_in("buy_insurance", %{"ready" => _ready, "wager" => _wager}, socket) do
    # user_id = socket.assigns.user.id
    # Casino.buy_insurance(user_id, wager, ready)
    {:noreply, socket}
  end

  def handle_in("split", %{"split" => _split}, socket) do
    # user_id = socket.assigns.user.id
    # Casino.split(user_id, split)
    {:noreply, socket}
  end

  def handle_in("hit", _, socket) do
    # user_id = socket.assigns.user.id
    # Casino.hit(user_id)
    {:noreply, socket}
  end

  def handle_in("stand", _, socket) do
    # user_id = socket.assigns.user.id
    # Casino.stand(user_id)
    {:noreply, socket}
  end

  def handle_in("double_down", _, socket) do
    # user_id = socket.assigns.user.id
    # Casino.double_down(user_id)
    {:noreply, socket}
  end

  def handle_in("surrender", _, socket) do
    # user_id = socket.assigns.user.id
    # Casino.surrender(user_id)
    {:noreply, socket}
  end

  def handle_in(message, body, socket) do
    Logger.error("Unknown socket message: #{message}")
    IO.inspect(%{body: body, socket: socket})

    {:noreply, socket}
  end
end
