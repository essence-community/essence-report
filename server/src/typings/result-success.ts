/* tslint:disable */
export interface ResultSuccess {
    /**
     * Result
     */
    success: true;
    /**
     * ID queue
     */
    ck_id: string;
    /**
     * Status
     */
    cv_status: "add" | "processing" | "success" | "fault" | "delete";
}
