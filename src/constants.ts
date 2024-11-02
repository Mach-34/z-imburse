export const USDC_TOKEN = {
    symbol: "USDC",
    name: "Aztec USDC",
    decimals: 6
}

const createQuotedPrintableRegex = (str: string) => {
    // Escape regex special characters
    const escapedStr = str.replace(/([.*+?^${}()|\[\]\\])/g, '\\$1');
    // Split into individual characters
    const chars = escapedStr.split('');
    // Create a pattern that allows for '=\\r\\n' followed by optional whitespace between characters
    const pattern = chars.map(ch => `(?:=\\r\\n[ \\t]*)*${ch}`).join('');
    return pattern;
}

export const Regexes = {
    from: /[Ff]rom:.*<.*?>\r?\n|[Ff]rom:.*@[^\r\n]+\r?\n/,
    to: /[Tt]o:.*?<([^>]+)>|[Tt]o:.*?([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/,
    subject: /[Ss]ubject:.*\r?\n/,
    date: /[Dd]ate:.*\r?\n/,
    inReplyTo: /in-reply-to:<([^\/]+)\/([^\/]+)\/pull\/(\d+)@github\.com>/,
    cc: new RegExp(`cc:\\s*.+`, "mi"),
    fullHeader: (field: string) => new RegExp(`^${field[0]}${field.slice(1)}:\\s*.+`, "mi"),
    linodeBilledAmount: /\$\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?/,
    unitedTotal: /Total:<\/td><td style=3D"(?:[^"]|=\r?\n)*?">([\d]+\.[\d]{2} USD)<\/td>/
};