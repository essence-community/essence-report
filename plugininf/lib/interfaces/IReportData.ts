export interface IReportData {
    queueId: string;
    fileName: string;
    reportQuery: Record<string, string>[];
    reportParameter: Record<string, any>;
    reportConfigParameter: Record<string, any>;
    recipe: string;
    engine?: string;
    helpers?: string;
    content?: string;
    contentType?: string;
    archive?: boolean;
    templateAsset?: Buffer;
    formatParameter: Record<string, any>;
}
