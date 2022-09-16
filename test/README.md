# protobruh/test

We use an existing protobuf implementation ([protobuf.js](https://github.com/protobufjs/protobuf.js)) to encode and decode our test files and ensure that ours is up to spec.

- `generate.js`: Generate basic.bin and fuzzy.bin
- `check.js`: Check if fuzzy.bin.out and fuzzy.json match
