import * as vscode from 'vscode';
import { RegistryWatcher } from './registry';
import { WorkspaceTreeProvider } from './workspaceTree';
import { StatusBarManager } from './statusBar';

export function activate(context: vscode.ExtensionContext) {
    const treeProvider = new WorkspaceTreeProvider();
    const registryWatcher = new RegistryWatcher();
    const statusBar = new StatusBarManager();

    vscode.window.registerTreeDataProvider('workspacesTree', treeProvider);

    registryWatcher.onDidChange(() => {
        treeProvider.refresh();
        statusBar.update();
    });

    context.subscriptions.push(
        registryWatcher,
        statusBar,

        vscode.commands.registerCommand('ws-dashboard.refresh', () => {
            treeProvider.refresh();
            statusBar.update();
        }),

        vscode.commands.registerCommand('ws-dashboard.openDoc', (docPath: string) => {
            const uri = vscode.Uri.file(docPath);
            vscode.window.showTextDocument(uri);
        }),

        vscode.commands.registerCommand('ws-dashboard.filterActive', () => {
            treeProvider.setFilter('active');
            vscode.commands.executeCommand('setContext', 'ws-dashboard.filter', 'active');
            statusBar.update();
        }),

        vscode.commands.registerCommand('ws-dashboard.filterAll', () => {
            treeProvider.setFilter('all');
            vscode.commands.executeCommand('setContext', 'ws-dashboard.filter', 'all');
            statusBar.update();
        }),
    );

    vscode.commands.executeCommand('setContext', 'ws-dashboard.filter', 'active');
}

export function deactivate() {}
