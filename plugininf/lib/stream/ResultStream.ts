import {Readable} from "stream";
import {isArray} from "lodash";

export default function ResultStream(preData: Record<string, any> | Record<string, any>[]) {
    let index = 0;
    const data = isArray(preData) ? preData : [preData];

    return new Readable({
        objectMode: true,
        read(size: number) {
            const newIndex = index + size;

            data.slice(index, newIndex).forEach((item) => this.push(item));
            if (newIndex > data.length) {
                this.push(null);
                this.emit("close");
            }
            index = newIndex;
        },
    });
}
