/* tslint:disable */
export interface Execute {
    /**
     * ID report
     */
    ck_report: string;
    /**
     * Format report
     */
    ck_format: string;
    /**
     * Format report
     */
    cl_online?: boolean;
    /**
     * Parameter report
     */
    cct_parameter: {
        [key: string]: any;
    };
    cv_name?: string;
    session?: string;
}
