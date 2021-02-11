Title: CAT and Schnorr Tricks II
Date: 2021-02-10 23:59
Category: Programming Languages

[Part 1](https://www.wpsoftware.net/andrew/blog/cat-and-schnorr-tricks-i.html)

# Introduction
 
This is the second in a series of posts about about covenants in Bitcoin
using [Taproot](https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki)
and a (hypothetical) `CAT` opcode. Historically, and as has
been implemented in [Elements](https://github.com/ElementsProject/elements/),
`CAT` has been considered to be a covenant opcode only in conjunction with
`CHECKSIGFROMSTACK`.

In our last post we introduced the idea of using `CAT` and fixed Schnorr
signatures to create covenants, by allowing a Script writer to reconstruct a
transaction hash, fixing some elements of the transaction but leaving others
free. In this post we'll talk about **recursive covenants**, ones which use
covenant logic to require that coins being spent from a covenant only go to
the same (or similar) covenant.

# Fears About Recursive Covenants

Before we get into the technical details, let me provide some historical context
for recursive covenants and the controversy surrounding them.

The idea for covenants was first introduced by [Greg Maxwell in 2013](https://bitcointalk.org/index.php?topic=278122.0)
in a BitcoinTalk post that invited users to come up with outlandish malicious
applications for the tech. Users observed that they could be used to "permanently
taint" coins, e.g. by constructing one-way covenants which users could send
coins to, but the covenant logic prevented moving coins out of. They hinted,
without giving specifics, that such covenants could include data that would
enable surveillance or transaction censorship.

Meanwhile, in 2015 Blockstream launched [Elements Alpha with support for
covevants](https://blockstream.com/2016/11/02/en-covenants-in-elements-alpha/)
to encourage experimentation in a no-value setting. In early 2016,
[Möser, Eyal and Sirer](https://hackingdistributed.com/2016/02/26/how-to-implement-secure-bitcoin-vaults/)
described a "vault" construction which used covenants to prevent fast theft
of coins.

In May 2019, Jeremy Rubin [proposed a `CHECKOUTPUTSHASHVERIFY` opcode](https://lists.linuxfoundation.org/pipermail/bitcoin-dev/2019-May/016934.html)
for Bitcoin that would enable "a rudimentary, limited form of covenant which
does not bear the same technical and social risks of prior covenant designs".
This opcode was later replaced by `SECURETHEBAG` and then by `CHECKTEMPLATEVERIFY`,
which became [BIP 0119](https://github.com/bitcoin/bips/blob/master/bip-0119.mediawiki)
in January of 2020. In parallel, [Russell O'Connor](https://lists.linuxfoundation.org/pipermail/bitcoin-dev/2019-May/016946.html)
proposed simply adding `CHECKSIGFROMSTACK` and `CAT` to Bitcoin, to enable
covenants without the limits of Rubin's proposal. This received some
opposition and ultimately conversation died off, largely because of the
inefficiency of CAT+CHECKSIG style covenants, but also because of the lingering
stigma of fully-general covenants.

For several years, I shared these general fears, and while I was frustrated that
Bitcoin lacked any means to support vaults, velocity limits, options contracts
or timelocks greater than 65000 blocks, I wasn't comfortable supporting general
covenant functionality.

However, in the Fall of 2019, Ethan Heilman pointed out to me in
[private conversation](https://www.cambridgebrewingcompany.com/) that the
sorts of "permanently-tainted-coin covenants" that people were worried about could
be constructed today using `CHECKMULTISIG`. For example, Coinbase could hypothetically
refuse to allow withdrawals to any scripts that didn't require their signature
(or that of a regulator), saying that they would countersign future transactions
but only if the signature requirement were preserved. He pointed out that the
massive social and technical barriers preventing this from happening would also
prevent anybody using covenant opcodes to the same effect.

Essentially, you could create a poisonous covenant if you wanted, but wallets
wouldn't recognize them, they wouldn't be able to spend them, and users wouldn't
want them.

He later [issued a challenge on Twitter](https://twitter.com/Ethan_Heilman/status/1194624166093369345)
for anyone to come up with a technically feasible dark covenant, using any
opcode that had ever been proposed for Bitcoin, in exchange for a free coffee.
On Telegram, I and others offered extended Ethan's offer with various alcoholic
beverages. Incentivized by the free beer I'd promised to buy myself, I spent
several hours trying to construct such a thing, but to no avail. As of this
writing, nobody has successfully taken Ethan up on this challenge. 

This more-or-less convinced me that fear of covenants is overblown, and as this
blog series will illustrate, even if it weren't, it's impossible to avoid
covenants when extending Bitcoin anyway. It seems that the rest of the ecosystem
is coming around to this viewpoint, and I hope that we see some form of general
covenant seriously proposed for Bitcoin in the future.

Meanwhile, let's continue exploring what kind of covenants we can create with
the not-for-covenants opcode `CAT`.

# Vaults

In the next section we are going to describe a Vault construction, which consists
of two covenant scripts, which restrict how their coins can be spent.

First, there is a **vault output**, which requires a signature with a fixed
"hot key" and only allows coins to be sent to a **staging output**.

Second, the staging output allows coins to be spent in one of two ways:

1. After a timelock expires, the coins can move to a target destination, which
is set when coins are first moved to the staging output; or
2. At any time, by signing with a "cold key", the coins can be returned to the
same script, setting a new target destination and resetting the timelock.

The idea here is that the coins can lay dormant, and when the user wants to
move them, they first need to send them to a "waiting area" where they must
sit until a timelock has expired. Therefore, as long as the original user
has possession of the cold key, it is impossible for an attacker to get ahold
of the funds. At worst, an attacker who gains access to the cold key can
start an indefinite battle with the rightful owner, where they take turns
resetting the timelock, but neither actually gains access to the funds.

# Value Switching

As we observed in the previous post, there is no way (that I can find) to compute
a taproot commitment in Script+`CAT`, at least not without knowing the discrete
logarithm of the commitment. And unless we can construct a commitment using a
nothing-up-my-sleeve point, for which nobody knows the discrete logarithm, we
can't commit to a script.

This means that if we hope to create recursive covenants, we are limited to
sending coins only to the same destination from which they came from. (For
non-recursive covenants, we can send to any of a number of pre-computed output
scripts, but we cannot create them dynamically.) How, then, can we construct
a vault, which seems to require a dynamically-generated output in order that
the user can change the target destination?

In an early version of this post, I was going to describe a solution called
"value switching", where there would be a large number of predefined destinations,
and the user would choose which one by setting the low byte of the output value.
The script would then check this value (which is directly committed in the sighash)
when deciding what spends were allowable. The idea was that each tapleaf would
be "gated" on the input value's low byte being a specific number.

This seems generally useful, in that you can use it to build multi-script state
machines that have loops in them, so I'm mentioning it here, but actually I
don't think I need it for vaults, so I leave the details as an exercise for
the reader.

# Transaction Preimaging

Since the recursive structure of vaults is very simple (you can send coins from
the vault script to itself but the only other paths lead out of the covenant)
we do not need value switching. However, we do have this "target destination"
parameter that we need to set. Our strategy for handling this is as follows:

The vault script, which simply prevents the coins from moving anywhere except
to a staging output, requires that it be spent with exactly two outputs. The
covenant will restrict the first output such that its scriptPubKey will be
the staging script and its value equal to that of the input.

The second output has no restrictions on it, but serves three purposes:
* Most importantly, our target destination will be defined to have its scriptPubKey
* It is a change output for the transaction
* It is an output we can spend to use child-pays-for-parent to feebump the transaction

Since our restrictions are entirely on the output side of the equation, it is
easy to control this by using a `CAT` and `CHECKSIG` as in our last post,
requiring that the signature hash consist of the following data:

* `80`: `SIGHASH_ANYONECANPAY | ALL` (sign all outputs but only the current input)
* `20000000000000`: version 2, locktime 0
* `<32-byte hash of all outputs>`
* `01`: no annex
* `<36-byte outpoint being spent>`: irrelevant to us
* `<8-byte amount being spent>`: must match the first 8 bytes of the output hash
* `<35-byte spk of output being spent>`: irrelevant to us
* `<4-byte sequence number of output being spent>`: irrelevant to us

where the third item, the hash of all outputs, covers the following data

* `<8-byte amount>`: must equal input amount
* `<35-byte staging scriptpubkey>`: fixed
* `<43-byte second output>`: arbitrary but must be length-checked and checked that its 9th byte is decimal 34

It is fairly straightforward, but tedious, to implement these restrictions using
the techniques discussed in the previous blog post. In the interest of keeping
this series moving forward, I will elide details for now, and later edit the post
when these are actually implemented, perhaps on Elements. Remember that in addition
to the covenant restrictions, there should be a signature requirement from the
user's hot key.

This second output may seem eyebrow-raising. I am ascribing it meaning but so
far our covenant has made no effort to restrict it or use it in any way. To
see where the interesting step comes in, let's look at the staging output's
script.

Recall that there are two ways to spend the staging output: by waiting for the
timelock and then sending to the target destination, or by signing with the cold
key and sending back to the staging output, resetting the clock.

Let's cover the second first, since it's simpler: it is essentially identical
to the vault script, except for two differences!

* The cold key is used in place of the hot key
* We cannot fix the output scriptPubKey without attempting to store the script's
own hash inside the script. So rather than enforcing that the coins go to a fixed
destination, we ensure that the input value+scriptPubKey (included in the BIP-0341` SigMsg`)
matches the output scriptPubKey (by checking that `sha_outputs` included in
`SigMsg` is the hash of some data starting with the required value+scriptPubKey).

Next, we consider the "unvaulting" spending path, in which the user waits for
the timelock to expire and then moves the coins to the target destination. The
covenant script needs to check that the coins actually do move to the target
destination.

Again, we elide the exact script details, but the premise is simple: we check
that the `sha_outputs` of `SigMsg` field begins with the input value followed
by the target scriptPubKey, where the "target scriptPubKey" is determined by
hashing the entire funding transaction, checking its txid against the input
outpoint in `SigMsg`, and copying the second output's scriptPubKey.

We observe that there is no need to enforce, at funding time, that the funding
transaction is well-formed (has a second output, whose scriptPubKey has the
right size, etc). If any of these conditions fail, the coins will be stuck in
the staging output until the user uses the coin key to re-fund with a well-formed
transaction.

# Conclusion

Although we elided many details, in this post we covered two ways to produce
recursive covenants using `CAT`: value switching and transaction preimaging.
We used these techniques to implement a vault.

In our next post, we'll talk about how to use these techniques to emulate
the "rebinding" functionality that Lightning Network developers have proposed
to get from `SIGHASH_ANYPREVOUT`, showing that `CAT` is sufficient to get
constant-sized payment channel backups.

In our concluding post, we will look at using the Miniscript model of Script
to make these complex and difficult-to-analyze Script constructions tractable.



