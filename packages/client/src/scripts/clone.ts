// structredCloneが遅いため
// SEE: http://var.blog.jp/archives/86038606.html

type Cloneable = string | number | boolean | null | { [key: string]: Cloneable | undefined } | Cloneable[];

export const deepClone = <T extends Cloneable>(x: T): T => {
	if (typeof x === 'object') {
		if (x === null) return x;
		if (Array.isArray(x)) return x.map(deepClone) as T;
		const obj = {} as Record<string, Cloneable>;
		for (const [k, v] of Object.entries(x)) {
			if (v !== undefined) {
				obj[k] = v;
			}
		}
		return obj as T;
	} else {
		return x;
	}
};
