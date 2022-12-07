const state = {
  state: "inProgress",
  minimumWager: 20,
  playerTurn: "12345",
  dealerHand: [
    {
      suit: "spades",
      card: "ace",
      faceDown: true,
    },
    {
      suit: "clubs",
      card: "jack",
    },
  ],
  activeHand: 12345,
  players: [
    {
      name: "tanner",
      id: 12345,
      chips: 500,
      insurance: 0,
      hands: [
        {
          id: 12345,
          complete: false,
          wager: 20, // if the person does not have a wager they are not playing.
          hand: [
            {
              suit: "spades",
              card: "ace",
            },
            {
              suit: "clubs",
              card: "jack",
            },
          ],
        },
      ],
    },
  ],
};
