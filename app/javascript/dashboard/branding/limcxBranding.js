export const DEFAULT_PLATFORM_BRANDING = Object.freeze({
  appName: 'Aurora Inbox',
  productName: 'LimCX',
  creator: 'Arjun Shaw',
  fullLogo: '',
  compactLogo: '',
  favicon: '',
  loginBranding: 'Premium omnichannel support by LimCX',
  accentColor: '#22D3EE',
  primaryColor: '#1677FF',
  supportURL: 'https://support.limcx.local',
  documentationURL: 'https://docs.limcx.local',
});

export const BRANDING_UI_SETTINGS_KEY = 'limcx_platform_branding';

export const getPlatformBranding = (uiSettings = {}) => ({
  ...DEFAULT_PLATFORM_BRANDING,
  ...(uiSettings?.[BRANDING_UI_SETTINGS_KEY] || {}),
});

export const getBrandLogo = (branding, mode = 'full') => {
  if (mode === 'compact') {
    return branding.compactLogo || branding.fullLogo || '';
  }
  return branding.fullLogo || '';
};

export const readLogoUpload = file =>
  new Promise((resolve, reject) => {
    if (!file) {
      resolve('');
      return;
    }

    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
