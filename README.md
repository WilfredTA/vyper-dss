# Vyper DSS

A WIP port of the core Maker protocol to the vyper language.

This code is experimental and the goal of this port is purely educational. It is very likely that there are errors in this implementation that are absent in the deployed solidity version.

Due to differences between vyper and solidity, the port is not exact. As one example, the solidity version of dss makes extensive use of function overloading, which is only partially supported in vyper via default param values, which, due to the ordering of the params in the solidity contracts, is not portable to vyper.

## To Do
- Check costs and correctness of using so many conversions
- Research tradeoffs between manual fixed point math operations (analogous to DS-Math used in canonical dss system) vs built-in decimal type
- Test the conversion of strings to bytes32 in the `Vat.file` and `Vat.file_ilk`
- Tradeoffs of using convenience method `self._auth` versus simply placing the `assert` in each function that calls it (`self._auth` is meant to mimic the `auth` modifier from `vat.sol`) 


While some of the contracts may be very similar to their solidity counterparts, the goal is not to produce a perfect copy in a different language. As this experiment continues, tests and profiling will be added which may motivate significant changes & divergences. A side effect of this may be insights into ways to improve the contracts later on. Further, given the educational motivation of this project, it is likely that some of the code is not aligned with vyper conventions (mostly out of ignorance). For example, in `Vat.vy`, there is extensive use of signed integers to enable functions to add or subtract from stored values, which is just like it is done in vat.sol. Due to vyper's type system and the fact that it's using vyper 0.2.12 (which does not provide an `abs` builtin function), conversions of negative integers do this: `convert(negative_int * -1, uint256)`. Whether this has edge cases or not based on how these operations are handled internally is TBD.. Whether it is the "vyper" way is also TBD (it might be better to provide two different functions based on the direction that values are meant to be moved, rather than using the signedness of an integer to guide that logic... and then I could remove type conversions entirely).