export const Regexes = {
    from: /[Ff]rom:.*<.*?>\r?\n|[Ff]rom:.*@[^\r\n]+\r?\n/,
    to: /[Tt]o:.*?<([^>]+)>|[Tt]o:.*?([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/,
    subject: /[Ss]ubject:.*\r?\n/,
    username: /Hello ([A-Za-z0-9]+-?[A-Za-z0-9]+),\r\n/,
    author: /Author\s*<author@noreply\.github\.com>/,
    inReplyTo: /in-reply-to:<([^\/]+)\/([^\/]+)\/pull\/(\d+)@github\.com>/,
    cc: new RegExp(`cc:\\s*.+`, "mi"),
    prData: /<([^>]+)>|([^\s,<>]+@[^\s,<>]+)/,
    fullHeader: (field: string) => new RegExp(`^${field[0]}${field.slice(1)}:\\s*.+`, "mi"),
    linodeBilledAmount: /\$\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?/,
};