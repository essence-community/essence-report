import { isEmpty } from "@essence-report/plugininf/lib/utils/Base";
import { ResultFault } from "../typings/result-fault";

export class NotFound implements ResultFault {
    public success: false = false;
    public "ck_error" = "not_found";
    public "cv_message" = "Not found";
    constructor(cvMesssage?: string) {
        if (!isEmpty(cvMesssage)) {
            this.cv_message = cvMesssage;
        }
    }
}
