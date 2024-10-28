export const USDC_TOKEN = {
    symbol: "USDC",
    name: "Aztec USDC",
    decimals: 6
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