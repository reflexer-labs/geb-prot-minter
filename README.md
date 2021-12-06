# GEB Protocol Token Minter

This is a suite of smart contracts meant to autonomously print new GEB protocol tokens and send them to a pre-specified address.

Specifically, there are two different contracts that can mint tokens:

- DecreasingProtocolTokenMinter: this contract mints a decreasing amount of tokens each week until it hits a stage where it goes into terminal inflation
- FixedProtocolTokenMinter: this contract mints a fixed amount of tokens each week until it hits a stage where it goes into terminal inflation
