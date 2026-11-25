import type { Vulnerability } from '../types.ts';
import { asArray, cleanText, fetchJson, truncate } from '../util.ts';

export const KEV_URL = 'https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json';

interface KevEntry {
  cveID?: string;
  vendorProject?: string;
  product?: string;
  vulnerabilityName?: string;
  dateAdded?: string;
  shortDescription?: string;
  requiredAction?: string;
  dueDate?: string;
  knownRansomwareCampaignUse?: string;
  cwes?: string[];
}

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const CVE_RE = /^CVE-\d{4}-\d{4,}$/;

/** CISA KEV kataloğundan en son eklenen kayıtları döndürür. */
export function parseKev(data: { vulnerabilities?: KevEntry[] }, limit = 120): Vulnerability[] {
  const out: Vulnerability[] = [];
  for (const entry of data.vulnerabilities ?? []) {
    const cveId = String(entry.cveID ?? '').trim().toUpperCase();
    const dateAdded = String(entry.dateAdded ?? '').trim();
    if (!CVE_RE.test(cveId) || !DATE_RE.test(dateAdded)) continue;
    const dueDate = String(entry.dueDate ?? '').trim();
    out.push({
      id: cveId,
      cveId,
      vendor: cleanText(entry.vendorProject ?? '') || 'Bilinmiyor',
      product: cleanText(entry.product ?? '') || 'Bilinmiyor',
      nameOriginal: truncate(cleanText(entry.vulnerabilityName ?? ''), 200),
      descriptionOriginal: truncate(cleanText(entry.shortDescription ?? ''), 900),
      actionOriginal: truncate(cleanText(entry.requiredAction ?? ''), 500),
      nameTr: null,
      descriptionTr: null,
      actionTr: null,
      dateAdded,
      dueDate: DATE_RE.test(dueDate) ? dueDate : null,
      ransomware: String(entry.knownRansomwareCampaignUse ?? '').toLowerCase() === 'known',
      cwes: asArray(entry.cwes).map(String).filter((c) => /^CWE-\d+$/.test(c)),
      nvdUrl: `https://nvd.nist.gov/vuln/detail/${cveId}`,
      translated: false,
      explanationTr: null,
      writer: null,
    });
  }
  out.sort((a, b) => (a.dateAdded === b.dateAdded ? b.cveId.localeCompare(a.cveId) : b.dateAdded.localeCompare(a.dateAdded)));
  return out.slice(0, limit);
}

export async function fetchKev(): Promise<Vulnerability[]> {
  const data = await fetchJson<{ vulnerabilities?: KevEntry[] }>(KEV_URL, { timeoutMs: 40_000 });
  return parseKev(data);
}
