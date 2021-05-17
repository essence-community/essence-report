/* tslint:disable */
import { ResultFault } from "./result-fault";
import { ResultSuccess } from "./result-success";

export type StoreGetResponse<
    TCode extends 200 = 200,
    TContentType extends "application/json" | "*/*" = "application/json" | "*/*"
> = TCode extends 200
    ? TContentType extends "application/json"
        ? /**
           * Files
           */
          ResultSuccess | ResultFault
        : TContentType extends "*/*"
        ? /**
           * Files
           */
          string
        : any
    : any;
