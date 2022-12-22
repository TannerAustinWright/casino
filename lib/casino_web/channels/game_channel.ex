defmodule CasinoWeb.GameChannel do
  use Phoenix.Channel

  require Logger

  def join("game:lobby", _message, socket) do
    Casino.join(socket.assigns.player.id)
    {:ok, socket}
  end

  # broadcast!(socket, "out_server_socket", params)
  def handle_in("bet", %{"wager" => wager}, socket) do
    player_id = socket.assigns.player.id
    Casino.bet(player_id, wager)
    {:noreply, socket}
  end

  def handle_in("insurance", %{"insurance" => insurance}, socket) do
    player_id = socket.assigns.player.id
    Casino.buy_insurance(player_id, insurance)
    {:noreply, socket}
  end

  def handle_in("split", _, socket) do
    player_id = socket.assigns.player.id
    Casino.split(player_id)
    {:noreply, socket}
  end

  def handle_in("hit", _, socket) do
    player_id = socket.assigns.player.id
    Casino.hit(player_id)
    {:noreply, socket}
  end

  def handle_in("stand", _, socket) do
    player_id = socket.assigns.player.id
    Casino.stand(player_id)
    {:noreply, socket}
  end

  def handle_in("double", _, socket) do
    player_id = socket.assigns.player.id
    Casino.double_down(player_id)
    {:noreply, socket}
  end

  def handle_in("surrender", _, socket) do
    # player_id = socket.assigns.player.id
    # Casino.surrender(player_id)
    {:noreply, socket}
  end

  def handle_in(message, body, socket) do
    Logger.error("Unknown socket message: #{message}")
    IO.inspect(%{body: body, socket: socket})

    {:noreply, socket}
  end
end
