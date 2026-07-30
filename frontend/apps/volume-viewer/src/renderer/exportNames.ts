const safePart = (value: string, fallback: string): string => {
  const normalized = value
    .normalize('NFKC')
    .replace(/[<>:"/\\|?*\u0000-\u001f]/g, '-')
    .replace(/\s+/g, '_')
    .replace(/[.-]+$/g, '')
    .slice(0, 96);
  return normalized || fallback;
};

export const volumeExportStem = (
  sourceName: string,
  channelId: string,
): string =>
  `${safePart(sourceName, 'volume')}.${safePart(channelId, 'channel')}`;

export const sliceExportStem = (
  sourceName: string,
  channelId: string,
  axis: 'i' | 'j' | 'k',
  index: number,
): string =>
  `${volumeExportStem(sourceName, channelId)}.slice-${axis}${Math.max(0, Math.round(index))}`;
