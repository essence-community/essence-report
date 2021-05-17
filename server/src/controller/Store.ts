import { GET, Path, QueryParam, Accept, Return } from "typescript-rest";
import { ResultSuccess, ResultFault } from "../typings";
import storeService from "../service/StoreService";

/**
 * Run build report
 */
@Path("/store")
@Accept("application/json")
export class StoreController {
    /**
     * Status report in queue.
     */
    @GET
    public async Get(
        @QueryParam("ck_queue") ckQueue: string,
        @QueryParam("session") session?: string,
    ): Promise<Return.DownloadBinaryData | ResultSuccess | ResultFault> {
        return storeService.runGet(ckQueue, session);
    }
}
