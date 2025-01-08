import React, { useState, useEffect } from 'react';

// Internationalization dictionary
const i18n = {
  en: {
    title: 'Installation of Adm Agent',
    description: 'We provide a bash script that automatically downloads the latest version of Adm Agent and configures the systemd service on Linux distributions:',
    moreHelp: 'For more help about this script, please refer to the ',
    serverInstallScript: 'Admin.IM Documentation',
    installTips: 'Installation Tips',
    tips: [
      'Ensure systemd, bash and curl is installed on your system.',
      'Root or sudo are only required for installation. Not required when the agent is running.',
      'This script only installs shared nodes. To deploy private nodes, please go to the control panel to obtain the installation command.',
    ],
    versionLabel: 'Latest Version:',
    dateLabel: 'Release Date:',
    sharedName: 'Shared Name',
    sharedNamePlaceholder: 'Optional: Specify a name for your instance',
    installation: 'Installation',
    uninstall: 'Uninstall',
    copy: 'Copy',
    copyright: 'Copyright © 2024 - 2025 Admin.IM'
  },
  zh: {
    title: 'Adm Agent部署脚本',
    description: '使用下面的一键部署脚本，快速共享您的闲置节点：',
    moreHelp: '更多部署说明，请参阅 ',
    serverInstallScript: 'Admin.IM 安装文档',
    installTips: '安装提示',
    tips: [
      '确保您的系统支持systemd，并已安装 bash、curl。',
      '安装时需要 root 权限或 sudo 执行脚本，运行时不需要。',
      '本命令仅适用共享节点，私有节点请部署服务端后至控制面板获取安装命令。',
    ],
    versionLabel: '最新版本:',
    dateLabel: '发布日期:',
    sharedName: '共享名称',
    sharedNamePlaceholder: '可选：为您共享的节点指定一个名称',
    installation: '安装',
    uninstall: '卸载',
    copy: '复制',
    copyright: 'Copyright © 2024 - 2025 Admin.IM'
  }
};

const LinuxInstallationPage = () => {
  const [versionInfo, setVersionInfo] = useState(null);
  const [language, setLanguage] = useState('en');
  const [shareName, setShareName] = useState('');
  const [installUrl, setInstallUrl] = useState('');
  const [installCommand, setInstallCommand] = useState('');

  // Detect browser language
  useEffect(() => {
    const browserLang = navigator.language.startsWith('zh') ? 'zh' : 'en';
    setLanguage(browserLang);
  }, []);

  // Dynamically set installation URL with full protocol and host
  useEffect(() => {
    const fullUrl = window.location.href;
    const urlObj = new URL(fullUrl);
    const baseUrl = `${urlObj.protocol}//${urlObj.host}`;
    setInstallUrl(baseUrl);
  }, []);

  // Fetch version information
  useEffect(() => {
    const fetchVersionInfo = async () => {
      try {
        const response = await fetch('/release/latest/metadata.json');
        const data = await response.json();
        setVersionInfo(data);
      } catch (error) {
        console.error('Failed to fetch version information:', error);
      }
    };

    fetchVersionInfo();
  }, []);

  // Update install command when URL or shareName changes
  useEffect(() => {
    const baseCommand = `bash <(curl -fsSL ${installUrl}) -share yes`;
    const newCommand = shareName 
      ? `${baseCommand} --sharename ${shareName}` 
      : baseCommand;
    setInstallCommand(newCommand);
  }, [installUrl, shareName]);

  const copyToClipboard = () => {
    navigator.clipboard.writeText(installCommand);
  };
  
  const lang = i18n[language];

  return (
    <div className="min-h-screen bg-gray-100 flex flex-col items-center justify-center p-4">
      <div className="bg-white shadow-lg rounded-lg max-w-3xl w-full p-8 mb-4">
        <div className="flex justify-between items-center mb-6">
          <h1 className="text-3xl font-bold text-gray-800">{lang.title}</h1>
          {versionInfo && (
            <div className="text-sm text-gray-600 text-right">
              <div>{lang.versionLabel} {versionInfo.tag}</div>
              <div>{lang.dateLabel} {new Date(versionInfo.date).toLocaleDateString()}</div>
            </div>
          )}
        </div>
        
        <div className="bg-gray-50 border border-gray-200 rounded-lg p-6 mb-6">
          <p className="text-gray-700 mb-4">
            {lang.description}
          </p>
          
          <div className="mb-4">
            <label htmlFor="shareName" className="block text-sm font-medium text-gray-700 mb-2">
              {lang.sharedName}
            </label>
            <input 
              id="shareName"
              type="text" 
              value={shareName}
              maxLength={10}
              onChange={(e) => setShareName(e.target.value)}
              placeholder={lang.sharedNamePlaceholder}
              className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              <strong>{lang.installation}</strong>
            </label>
            <div className="flex items-center bg-gray-100 rounded-md p-3 mb-4">
              <div className="flex-grow overflow-x-auto bg-gray-100 rounded-md p-2">
                <code className="block text-sm text-gray-800 whitespace-nowrap">
                  {installCommand}
                </code>
              </div>
              <button 
                onClick={copyToClipboard}
                className="ml-4 bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600 transition-colors flex-shrink-0"
              >
                {lang.copy}
              </button>
            </div>
          </div>
          
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              <strong>{lang.uninstall}</strong>
            </label>
            <div className="flex items-center bg-gray-100 rounded-md p-3">
              <div className="flex-grow overflow-x-auto bg-gray-100 rounded-md p-2">
                <code className="block text-sm text-gray-800 whitespace-nowrap">
                  {`bash <(curl -fsSL ${installUrl}) uninstall`}
                </code>
              </div>
              <button 
                onClick={() => {
                  navigator.clipboard.writeText(`bash <(curl -fsSL ${installUrl}) uninstall`);
                }}
                className="ml-4 bg-red-500 text-white px-4 py-2 rounded hover:bg-red-600 transition-colors flex-shrink-0"
              >
                {lang.copy}
              </button>
            </div>
          </div>
          
          <p className="text-sm text-gray-600">
            {lang.moreHelp}<a href="https://doc.admin.im" className="text-blue-500 hover:underline">{lang.serverInstallScript}</a>
          </p>
        </div>
        
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <h2 className="text-xl font-semibold text-blue-800 mb-3">{lang.installTips}</h2>
          <ul className="list-disc list-inside text-gray-700 space-y-2">
            {lang.tips.map((tip, index) => (
              <li key={index}>{tip}</li>
            ))}
          </ul>
        </div>
      </div>

      <footer className="fixed bottom-0 left-0 w-full text-center text-gray-500 text-sm py-4 bg-white shadow-md">
        {lang.copyright}
      </footer>
    </div>
  );
};

export default LinuxInstallationPage;