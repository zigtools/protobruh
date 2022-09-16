const fs = require("fs");
const path = require("path");
const protobuf = require("protobufjs");

(async () => {
    const root = await protobuf.load(path.join(__dirname, "scip/scip.proto"));

    const Index = root.lookupType("scip.Index");
    const actual = Index.decode(fs.readFileSync(path.join(__dirname, "scip/fuzzy.bin.out"))).toJSON();
    const expected = JSON.parse(fs.readFileSync(path.join(__dirname, "scip/fuzzy.json")).toString());

    console.log(JSON.stringify(actual) === JSON.stringify(expected));
})();
