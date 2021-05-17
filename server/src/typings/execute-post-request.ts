/* tslint:disable */
import { Execute } from "./execute";

export type ExecutePostRequest<
    TCode extends "application/json" = "application/json"
> = TCode extends "application/json" ? Execute : any;
