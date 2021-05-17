/* tslint:disable */
import { ResultFault } from "./result-fault";
import { ResultSuccess } from "./result-success";

export type ExecuteDeleteResponse<
    TCode extends 200 = 200,
    TContentType extends "application/json" = "application/json"
> = TCode extends 200
    ? TContentType extends "application/json"
        ? /**
           * Delete report
           */
          ResultSuccess | ResultFault
        : any
    : any;
