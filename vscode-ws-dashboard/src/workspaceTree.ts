import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import { loadRegistry, Workspace } from './registry';

export type Filter = 'active' | 'all';

export class WorkspaceTreeProvider implements vscode.TreeDataProvider<WorkspaceItem> {
    private _onDidChangeTreeData = new vscode.EventEmitter<WorkspaceItem | undefined>();
    readonly onDidChangeTreeData = this._onDidChangeTreeData.event;
    private filter: Filter = 'active';

    refresh() {
        this._onDidChangeTreeData.fire(undefined);
    }

    setFilter(filter: Filter) {
        this.filter = filter;
        this.refresh();
    }

    getFilter(): Filter {
        return this.filter;
    }

    getTreeItem(element: WorkspaceItem): vscode.TreeItem {
        return element;
    }

    getChildren(element?: WorkspaceItem): WorkspaceItem[] {
        const workspaces = loadRegistry();

        if (!element) {
            const filtered = this.applyFilter(workspaces);
            const roots = filtered.filter(ws => !ws.parent);
            const orphans = filtered.filter(ws => {
                if (!ws.parent) return false;
                return !workspaces.find(w => w.name === ws.parent);
            });
            return [...roots, ...orphans].map(ws =>
                this.createItem(ws, workspaces)
            );
        }

        const children = workspaces.filter(ws => ws.parent === element.wsName);
        const filtered = this.applyFilter(children);
        return filtered.map(ws => this.createItem(ws, workspaces));
    }

    private applyFilter(workspaces: Workspace[]): Workspace[] {
        if (this.filter === 'all') return workspaces;
        return workspaces.filter(ws => ws.tags.includes('active'));
    }

    private createItem(ws: Workspace, all: Workspace[]): WorkspaceItem {
        const hasChildren = all.some(w => w.parent === ws.name);
        const isDone = ws.tags.includes('done');
        const collapsible = hasChildren
            ? vscode.TreeItemCollapsibleState.Expanded
            : vscode.TreeItemCollapsibleState.None;

        return new WorkspaceItem(ws, collapsible, isDone);
    }

    getWorkspaces(): Workspace[] {
        return loadRegistry();
    }
}

export class WorkspaceItem extends vscode.TreeItem {
    readonly wsName: string;
    readonly wsPath: string;

    constructor(
        ws: Workspace,
        collapsibleState: vscode.TreeItemCollapsibleState,
        isDone: boolean,
    ) {
        super(ws.name, collapsibleState);

        this.wsName = ws.name;
        this.wsPath = ws.path;
        this.description = ws.desc;
        this.tooltip = new vscode.MarkdownString();
        this.tooltip.appendMarkdown(`**${ws.name}**\n\n`);
        this.tooltip.appendMarkdown(`${ws.desc}\n\n`);
        this.tooltip.appendMarkdown(`Path: \`${ws.path}\``);
        if (ws.parent) {
            this.tooltip.appendMarkdown(`\n\nParent: ${ws.parent}`);
        }

        if (isDone) {
            this.iconPath = new vscode.ThemeIcon('check', new vscode.ThemeColor('charts.green'));
        } else if (fs.existsSync(ws.path)) {
            this.iconPath = new vscode.ThemeIcon('circle-filled', new vscode.ThemeColor('charts.blue'));
        } else {
            this.iconPath = new vscode.ThemeIcon('circle-outline');
        }

        if (fs.existsSync(ws.path)) {
            this.command = {
                command: 'ws-dashboard.openDoc',
                title: 'Open Workspace Doc',
                arguments: [ws.path],
            };
        }

        this.contextValue = isDone ? 'workspace-done' : 'workspace-active';
    }
}
