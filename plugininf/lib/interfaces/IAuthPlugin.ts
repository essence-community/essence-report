import {ISessionData} from "./ISessionData";

export interface IAuthPlugin {
    init(): Promise<void>;
    checkSession(session?: string): Promise<false | ISessionData>;
}
