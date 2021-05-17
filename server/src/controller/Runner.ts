import { GET, Path, QueryParam, Accept } from "typescript-rest";
import { isEmpty } from "@essence-report/plugininf/lib/utils/Base";
import { ResultSuccess, ResultFault } from "../typings";
import reportSystem from "../service/ReportSystem";
import { QueueStatus } from "../dto/QueueStatus";
import { NotFound } from "../dto/NotFound";
import { Fault } from "../dto/Fault";

/**
 * Run build report
 */
@Path("/runner")
@Accept("application/json")
export class RunnerController {
    /**
     * Status report in queue.
     */
    @GET
    public async Get(
        @QueryParam("ck_queue") ckQueue: string,
    ): Promise<ResultSuccess | ResultFault> {
        if (isEmpty(ckQueue)) {
            return new NotFound("Not found require parameter ck_queue");
        }
        try {
            await reportSystem.runReport(ckQueue);
        } catch (err) {
            return new Fault("system_error", err.message);
        }

        return QueueStatus.getStatusByQueue(ckQueue);
    }
}
