import * as vscode from 'vscode';
import { loadRegistry } from './registry';

export class StatusBarManager implements vscode.Disposable {
    private item: vscode.StatusBarItem;

    constructor() {
        this.item = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 50);
        this.item.command = 'workspacesTree.focus';
        this.update();
        this.item.show();
    }

    update() {
        const workspaces = loadRegistry();
        const active = workspaces.filter(ws => ws.tags.includes('active'));
        const done = workspaces.filter(ws => ws.tags.includes('done'));

        const duePings = active.reduce((count, ws) => {
            if (!ws.pings) return count;
            const now = new Date();
            return count + ws.pings.filter(p => !p.done && new Date(p.due) <= now).length;
        }, 0);

        let text = `$(layers) WS: ${active.length} active`;
        if (done.length > 0) {
            text += ` · ${done.length} done`;
        }
        if (duePings > 0) {
            text += ` · $(bell) ${duePings}`;
            this.item.backgroundColor = new vscode.ThemeColor('statusBarItem.warningBackground');
        } else {
            this.item.backgroundColor = undefined;
        }

        this.item.text = text;
        this.item.tooltip = `${active.length} active workspaces, ${done.length} done` +
            (duePings > 0 ? `, ${duePings} overdue pings` : '');
    }

    dispose() {
        this.item.dispose();
    }
}
