const fs = require("fs");
const path = require("path");
const diff = require("diff");
const protobuf = require("protobufjs");

(async () => {
    const root = await protobuf.load(path.join(__dirname, "scip/scip.proto"));

    const Index = root.lookupType("scip.Index");
    const actual = Index.decode(fs.readFileSync(path.join(__dirname, "scip/fuzzy.bin.out"))).toJSON();
    const expected = JSON.parse(fs.readFileSync(path.join(__dirname, "scip/fuzzy.json")).toString());

    const isCorrect = JSON.stringify(actual) === JSON.stringify(expected);
    console.log("isCorrect: " + isCorrect)
    if (!isCorrect) {
        const d = diff.diffJson(expected, actual);
        for (const part of d) {
            const color = part.added ? '+' :
                part.removed ? '-' : '*';
            for (const line of part.value.split("\n")) {
                console.error(`${color} ${line}`);
            }
            // console.log(`${part.value}`);
        }
    }
    process.exit(isCorrect ? 0 : 1);
})();
