import { ISessionData } from "@essence-report/plugininf/lib/interfaces/ISessionData";
import { IAuthPlugin } from "@essence-report/plugininf/lib/interfaces/IAuthPlugin";

export class NoAuth implements IAuthPlugin {
    public init(): Promise<void> {
        return Promise.resolve();
    }
    public checkSession(session?: string): Promise<false | ISessionData> {
        return Promise.resolve({
            session,
            ck_id: "-11",
        });
    }
}
