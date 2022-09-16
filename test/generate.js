const fs = require("fs");
const path = require("path");
const protobuf = require("protobufjs");

/**
 * @param {protobuf.Root} root
 * @param {protobuf.Enum} en
 * @returns {number}
 */
function fuzzEnum(root, en) {
    const values = Object.values(en.values);
    return values[Math.floor(Math.random() * values.length)];
}

/**
 * 
 * @param {protobuf.Root} root
 * @param {protobuf.Type} type 
 * @returns {protobuf.Message}
 */
function fuzzType(root, type) {
    var obj = {};
    
    // console.log(type.name);

    for (const [name, field] of Object.entries(type.fields)) {
        const res = root.lookup(field.type);
        let values = [];

        const e = field.repeated ? Math.ceil(Math.random() * 12) : 1;
        for (let i = 0; i < e; i++) {
            if (res) {
                values.push(res.values ? fuzzEnum(root, res) : fuzzType(root, res));
            } else {
                // console.log(`${name}: "${field.type}"`);
                if (field.type === "string") values.push(Math.random().toString(36).slice(2));
                else if (field.type === "int32") values.push(Math.floor(Math.random() * 100));
                else if (field.type === "bool") values.push(Math.random() > 0.5);
                else throw new Error("haze: " + field.type);
            }
        }

        obj[name] = field.repeated ? values : values[0];
    }
    
    // console.log(obj);

    const err = type.verify(obj);
    if (err) throw new Error(err);
    return type.create(obj);
}

(async () => {
    const root = await protobuf.load(path.join(__dirname, "scip/scip.proto"));

    const Index = root.lookupType("scip.Index");
    const Metadata = root.lookupType("scip.Metadata");
    const Document = root.lookupType("scip.Document");
    const ProtocolVersion = root.lookupEnum("scip.ProtocolVersion");
    const TextEncoding = root.lookupEnum("scip.TextEncoding");
    const SymbolInformation = root.lookupType("scip.SymbolInformation");

    // basic.bin
    const payload = {
        metadata: Metadata.create({
            version: ProtocolVersion.values.UnspecifiedProtocolVersion,
            toolInfo: {
                name: "joe",
                version: "mama",
                arguments: [ "amog", "us" ],
            },
            projectRoot: "C:\\Programming\\Zig\\scip-zig\\test",
            textDocumentEncoding: TextEncoding.values.UTF8,
        }),
        documents: [
            Document.create({
                language: "zig",
                relativePath: "loris.zig",
                occurrences: [],
                symbols: [
                    SymbolInformation.create({
                        symbol: "swag",
                        documentation: ["Is Loris swag?", "Yes"],
                        relationships: [],
                    }),
                ],
            }),
        ],
        externalSymbols: []
    }

    const errMsg = Index.verify(payload);
    if (errMsg)
        throw Error(errMsg);

    const message = Index.create(payload);
    const buffer = Index.encode(message).finish();
    fs.writeFileSync(path.join(__dirname, "scip/basic.bin"), buffer);

    // console.log(root.lookupType("scip.Diagnostica"));
    const ft = fuzzType(root, Index);
    fs.writeFileSync(path.join(__dirname, "scip/fuzzy.bin"), Index.encode(ft).finish());
    fs.writeFileSync(path.join(__dirname, "scip/fuzzy.json"), JSON.stringify(ft.toJSON(), null, 4));
})();
