# Crowdfunding Smart Contract

This is a decentralized crowdfunding smart contract written in **Solidity**. It allow users to create campaigns, 
contribute funds and manage withdrawals and refunds, based on campaign success.

## Features

> - **Create Campaigns** - Set a funding target and deadline (at least a week after campaign creation)
> - **Contribute** - Support campaigns by sending ETH.
> - **Withdraw** - Campaign Creator can withdraw funds if the goal is reached after the deadline.
> - **Refund** - Contributors can reclaim funds if the campaign fails to meet its goal after the deadline or is closed.

## Usage

> - Use `createCampaign(target, deadline)` to start a campaign.
> - Users can contribute via contribute `(campaignId)`
> - Creators withdraw funds with `withdraw(campaignId)` if the target is reached after the deadline.
> - Contributors can claim refunds with `refundContribution(campaignId)` if the campaign fails or is closed.

## Deployment

1. Clone the repository:
   ```bash
   git clone https://github.com/mitrev-g/My-Solidity-Projects.git
   cd crowdfunding-project
   ```
2. Install Foundry (if not already installed)
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```
3. Compile the files
   ```bash
   forge build
   ```

## Testing and Coverage
```bash
forge test
forge coverage
```
   


## Additional Notes

> - Campaign deadlines must be at least 7 days.
> - Contributions can't be 0.
> - All tests are written with Foundry.
