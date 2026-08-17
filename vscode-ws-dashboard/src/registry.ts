import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import * as yaml from 'js-yaml';
import * as vscode from 'vscode';

export interface Workspace {
    name: string;
    desc: string;
    path: string;
    tags: string[];
    parent?: string;
    pings?: Ping[];
}

export interface Ping {
    due: string;
    task: string;
    done?: boolean;
}

function getRegistryPath(): string {
    const configured = vscode.workspace.getConfiguration('wsDashboard').get<string>('registryPath');
    if (configured) {
        return configured.replace(/^~/, os.homedir());
    }
    return process.env['WORKSPACES'] || path.join(os.homedir(), 'workspaces.yaml');
}

export function loadRegistry(): Workspace[] {
    const registryPath = getRegistryPath();
    if (!fs.existsSync(registryPath)) {
        return [];
    }
    try {
        const content = fs.readFileSync(registryPath, 'utf8');
        const data = yaml.load(content) as any[];
        if (!Array.isArray(data)) {
            return [];
        }
        return data.map(item => ({
            name: item.name || '',
            desc: item.desc || '',
            path: (item.path || '').replace(/^\$HOME/, os.homedir()).replace(/^~/, os.homedir()),
            tags: item.tags || [],
            parent: item.parent,
            pings: item.pings,
        }));
    } catch {
        return [];
    }
}

export class RegistryWatcher implements vscode.Disposable {
    private watcher: fs.FSWatcher | undefined;
    private lastMtime: number = 0;
    private pollTimer: NodeJS.Timeout | undefined;
    private readonly _onDidChange = new vscode.EventEmitter<void>();
    readonly onDidChange = this._onDidChange.event;

    constructor() {
        this.start();
    }

    private start() {
        const registryPath = getRegistryPath();
        if (!fs.existsSync(registryPath)) {
            this.pollTimer = setInterval(() => {
                if (fs.existsSync(registryPath)) {
                    this.stop();
                    this.start();
                }
            }, 2000);
            return;
        }

        this.lastMtime = this.getMtime(registryPath);

        this.pollTimer = setInterval(() => {
            const mtime = this.getMtime(registryPath);
            if (mtime !== this.lastMtime) {
                this.lastMtime = mtime;
                this._onDidChange.fire();
            }
        }, 100);
    }

    private getMtime(filePath: string): number {
        try {
            return fs.statSync(filePath).mtimeMs;
        } catch {
            return 0;
        }
    }

    private stop() {
        if (this.watcher) {
            this.watcher.close();
            this.watcher = undefined;
        }
        if (this.pollTimer) {
            clearInterval(this.pollTimer);
            this.pollTimer = undefined;
        }
    }

    dispose() {
        this.stop();
        this._onDidChange.dispose();
    }
}
