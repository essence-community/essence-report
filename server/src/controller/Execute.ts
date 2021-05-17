import { GET, POST, DELETE, Path, QueryParam, Accept } from "typescript-rest";
import { Execute, ResultSuccess, ResultFault } from "../typings";
import executeService from "../service/ExecuteService";

/**
 * Work queue
 */
@Path("/execute")
@Accept("application/json")
export class ExecuteController {
    /**
     * Status report in queue.
     */
    @GET
    public async Get(
        @QueryParam("ck_queue") ckQueue: string,
        @QueryParam("session") session?: string,
    ): Promise<ResultSuccess | ResultFault> {
        return executeService.runGet(ckQueue, session);
    }
    /**
     * Add report in queue.
     */
    @POST
    public async Post(data: Execute): Promise<ResultSuccess | ResultFault> {
        return executeService.runPost(data);
    }
    /**
     * Remove queue.
     */
    @DELETE
    public async Delete(
        @QueryParam("ck_queue") ckQueue: string,
        @QueryParam("session") session?: string,
    ): Promise<ResultSuccess | ResultFault> {
        return executeService.runDelete(ckQueue, session);
    }
}
