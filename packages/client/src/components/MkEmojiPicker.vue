<template>
<div class="omfetrab" :class="['s' + size, 'w' + width, 'h' + height, { asDrawer, asWindow }]" :style="{ maxHeight: maxHeight ? maxHeight + 'px' : undefined }">
	<input ref="searchEl" :value="q" class="search" data-prevent-emoji-insert :class="{ filled: q != null && q != '' }" :placeholder="i18n.ts.search" type="search" @input="input()" @paste.stop="paste" @keydown.stop.prevent.enter="onEnter">
	<div ref="emojisEl" class="emojis">
		<section class="result">
			<div v-if="searchResultCustom.length > 0" class="body">
				<button
					v-for="emoji in searchResultCustom"
					:key="emoji.id"
					class="_button item"
					:title="`:${emoji.name}:`"
					tabindex="0"
					@click="chosen(emoji, $event)"
				>
					<MkEmoji class="emoji" :emoji="`:${emoji.name}:`"/>
				</button>
			</div>
			<div v-if="searchResultUnicode.length > 0" class="body">
				<button
					v-for="emoji in searchResultUnicode"
					:key="emoji.name"
					class="_button item"
					:title="emoji.name"
					tabindex="0"
					@click="chosen(emoji, $event)"
				>
					<MkEmoji class="emoji" :emoji="emoji.char"/>
				</button>
			</div>
		</section>

		<div v-if="tab === 'index'" class="group index">
			<section v-if="showPinned">
				<div class="body">
					<button
						v-for="emoji in pinned"
						:key="emoji"
						:data-emoji="emoji"
						class="_button item"
						tabindex="0"
						@pointerenter="computeButtonTitle"
						@click="chosen(emoji, $event)"
					>
						<MkEmoji class="emoji" :emoji="emoji" :normal="true"/>
					</button>
				</div>
			</section>

			<section>
				<header class="_acrylic"><i class="ti ti-clock ti-fw"></i> {{ i18n.ts.recentUsed }}</header>
				<div class="body">
					<button
						v-for="emoji in recentlyUsedEmojis"
						:key="emoji"
						class="_button item"
						:data-emoji="emoji"
						@pointerenter="computeButtonTitle"
						@click="chosen(emoji, $event)"
					>
						<MkEmoji class="emoji" :emoji="emoji" :normal="true"/>
					</button>
				</div>
			</section>
		</div>
		<div v-once class="group">
			<header class="_acrylic">{{ i18n.ts.customEmojis }}</header>
			<XSection
				v-for="category in customEmojiCategories"
				:key="`custom:${category}`"
				:initial-shown="false"
				:emojis="computed(() => customEmojis.filter(e => category === null ? (e.category === 'null' || !e.category) : e.category === category).map(e => `:${e.name}:`))"
				@chosen="chosen"
			>
				{{ category || i18n.ts.other }}
			</XSection>
		</div>
		<div v-once class="group">
			<header class="_acrylic">{{ i18n.ts.emoji }}</header>
			<XSection v-for="category in categories" :key="category" :emojis="emojiCharByCategory.get(category) ?? []" @chosen="chosen">{{ category }}</XSection>
		</div>
	</div>
</div>
</template>

<script lang="ts" setup>
import { ref, shallowRef, computed, watch, onMounted } from 'vue';
import { CustomEmoji } from 'misskey-js/built/entities';
import XSection from '@/components/MkEmojiPicker.section.vue';
import { emojilist, emojiCharByCategory, UnicodeEmojiDef, unicodeEmojiCategories as categories, getEmojiName } from '@/scripts/emojilist';
import MkRippleEffect from '@/components/MkRippleEffect.vue';
import * as os from '@/os';
import { isTouchUsing } from '@/scripts/touch';
import { deviceKind } from '@/scripts/device-kind';
import { emojiCategories, instance } from '@/instance';
import { i18n } from '@/i18n';
import { defaultStore } from '@/store';

const props = withDefaults(defineProps<{
	showPinned?: boolean;
	asReactionPicker?: boolean;
	maxHeight?: number;
	asDrawer?: boolean;
	asWindow?: boolean;
}>(), {
	maxHeight: undefined,
	showPinned: true,
});

const emit = defineEmits<{
	(ev: 'chosen', v: string): void;
}>();

const searchEl = shallowRef<HTMLInputElement>();
const emojisEl = shallowRef<HTMLDivElement>();

const {
	reactions: pinned,
	reactionPickerSize,
	reactionPickerWidth,
	reactionPickerHeight,
	recentlyUsedEmojis,
} = defaultStore.reactiveState;

const size = computed(() => props.asReactionPicker ? reactionPickerSize.value : 1);
const width = computed(() => props.asReactionPicker ? reactionPickerWidth.value : 3);
const height = computed(() => props.asReactionPicker ? reactionPickerHeight.value : 2);
const customEmojiCategories = emojiCategories;
const customEmojis = instance.emojis ?? [];
const q = ref<string>('');
const searchResultCustom = ref<CustomEmoji[]>([]);
const searchResultUnicode = ref<UnicodeEmojiDef[]>([]);
const tab = ref<'index' | 'custom' | 'unicode' | 'tags'>('index');

watch(q, () => {
	if (emojisEl.value) emojisEl.value.scrollTop = 0;

	if (q.value === '') {
		searchResultCustom.value = [];
		searchResultUnicode.value = [];
		return;
	}

	const newQ = q.value.replace(/:/g, '').toLowerCase();

	const searchCustom = (): Set<CustomEmoji> => {
		const max = 8;
		const emojis = customEmojis;
		const matches = new Set<CustomEmoji>();

		const exactMatch = emojis.find(emoji => emoji.name === newQ);
		if (exactMatch) matches.add(exactMatch);

		if (newQ.includes(' ')) { // AND検索
			const keywords = newQ.split(' ');

			// 名前にキーワードが含まれている
			for (const emoji of emojis) {
				if (keywords.every(keyword => emoji.name.includes(keyword))) {
					matches.add(emoji);
					if (matches.size >= max) break;
				}
			}
			if (matches.size >= max) return matches;

			// 名前またはエイリアスにキーワードが含まれている
			for (const emoji of emojis) {
				if (keywords.every(keyword => emoji.name.includes(keyword) || emoji.aliases.some(alias => alias.includes(keyword)))) {
					matches.add(emoji);
					if (matches.size >= max) break;
				}
			}
		} else {
			for (const emoji of emojis) {
				if (emoji.name.startsWith(newQ)) {
					matches.add(emoji);
					if (matches.size >= max) break;
				}
			}
			if (matches.size >= max) return matches;

			for (const emoji of emojis) {
				if (emoji.aliases.some(alias => alias.startsWith(newQ))) {
					matches.add(emoji);
					if (matches.size >= max) break;
				}
			}
			if (matches.size >= max) return matches;

			for (const emoji of emojis) {
				if (emoji.name.includes(newQ)) {
					matches.add(emoji);
					if (matches.size >= max) break;
				}
			}
			if (matches.size >= max) return matches;

			for (const emoji of emojis) {
				if (emoji.aliases.some(alias => alias.includes(newQ))) {
					matches.add(emoji);
					if (matches.size >= max) break;
				}
			}
		}

		return matches;
	};

	const searchUnicode = (): Set<UnicodeEmojiDef> => {
		const max = 8;
		const emojis = emojilist;
		const matches = new Set<UnicodeEmojiDef>();

		const exactMatch = emojis.find(emoji => emoji.name === newQ);
		if (exactMatch) matches.add(exactMatch);

		if (newQ.includes(' ')) { // AND検索
			const keywords = newQ.split(' ');

			// 名前にキーワードが含まれている
			for (const emoji of emojis) {
				if (keywords.every(keyword => emoji.name.includes(keyword))) {
					matches.add(emoji);
					if (matches.size >= max) break;
				}
			}
			if (matches.size >= max) return matches;

			// 名前またはエイリアスにキーワードが含まれている
			for (const emoji of emojis) {
				if (keywords.every(keyword => emoji.name.includes(keyword) || emoji.keywords.some(alias => alias.includes(keyword)))) {
					matches.add(emoji);
					if (matches.size >= max) break;
				}
			}
		} else {
			for (const emoji of emojis) {
				if (emoji.name.startsWith(newQ)) {
					matches.add(emoji);
					if (matches.size >= max) break;
				}
			}
			if (matches.size >= max) return matches;

			for (const emoji of emojis) {
				if (emoji.keywords.some(keyword => keyword.startsWith(newQ))) {
					matches.add(emoji);
					if (matches.size >= max) break;
				}
			}
			if (matches.size >= max) return matches;

			for (const emoji of emojis) {
				if (emoji.name.includes(newQ)) {
					matches.add(emoji);
					if (matches.size >= max) break;
				}
			}
			if (matches.size >= max) return matches;

			for (const emoji of emojis) {
				if (emoji.keywords.some(keyword => keyword.includes(newQ))) {
					matches.add(emoji);
					if (matches.size >= max) break;
				}
			}
		}

		return matches;
	};

	searchResultCustom.value = Array.from(searchCustom());
	searchResultUnicode.value = Array.from(searchUnicode());
});

const focus = (): void => {
	if (!['smartphone', 'tablet'].includes(deviceKind) && !isTouchUsing) {
		searchEl.value?.focus({
			preventScroll: true,
		});
	}
};

const reset = (): void => {
	if (emojisEl.value) emojisEl.value.scrollTop = 0;
	q.value = '';
};

const getKey = (emoji: string | CustomEmoji | UnicodeEmojiDef): string => {
	if (typeof emoji === 'string') return emoji;
	return 'char' in emoji ? emoji.char : `:${emoji.name}:`;
};

/** @see MkEmojiPicker.section.vue */
const computeButtonTitle = (ev: MouseEvent): void => {
	const el = ev.target;
	if (!(el instanceof HTMLElement)) return;
	const emoji = el.dataset.emoji;
	if (!emoji) return;
	el.title = emoji.startsWith(':') ? emoji : getEmojiName(emoji) ?? emoji;
};

const chosen = (emoji: string | CustomEmoji | UnicodeEmojiDef, ev?: MouseEvent): void => {
	const el = ev && (ev.currentTarget ?? ev.target);
	if (el instanceof HTMLElement) {
		const rect = el.getBoundingClientRect();
		const x = rect.left + (el.offsetWidth / 2);
		const y = rect.top + (el.offsetHeight / 2);
		os.popup(MkRippleEffect, { x, y }, {}, 'end');
	}

	const key = getKey(emoji);
	emit('chosen', key);

	// 最近使った絵文字更新
	if (!pinned.value.includes(key)) {
		let recents = defaultStore.state.recentlyUsedEmojis;
		recents = recents.filter(recentEmoji => recentEmoji !== key);
		recents.unshift(key);
		defaultStore.set('recentlyUsedEmojis', recents.splice(0, 32));
	}
};

const input = (): void => {
	// Using custom input event instead of v-model to respond immediately on
	// Android, where composition happens on all languages
	// (v-model does not update during composition)
	q.value = searchEl.value?.value.trim() ?? '';
};

const paste = (event: ClipboardEvent): void => {
	const pasted = event.clipboardData?.getData('text') ?? '';
	if (done(pasted)) {
		event.preventDefault();
	}
};

const onEnter = (ev: KeyboardEvent): void => {
	if (ev.isComposing || ev.key === 'Process' || ev.keyCode === 229) return;
	done();
};

const done = (query_?: string): boolean | void => {
	const query = query_ ?? q.value;
	const q2 = query.startsWith(':') ? query.slice(1, -1) : query;
	const exactMatchCustom = customEmojis.find(emoji => emoji.name === q2);
	if (exactMatchCustom) {
		chosen(exactMatchCustom);
		return true;
	}
	const exactMatchUnicode = emojilist.find(emoji => emoji.char === q2 || emoji.name === q2);
	if (exactMatchUnicode) {
		chosen(exactMatchUnicode);
		return true;
	}
	if (searchResultCustom.value.length > 0) {
		chosen(searchResultCustom.value[0]);
		return true;
	}
	if (searchResultUnicode.value.length > 0) {
		chosen(searchResultUnicode.value[0]);
		return true;
	}
};

onMounted(() => {
	focus();
});

defineExpose({
	focus,
	reset,
});
</script>

<style lang="scss" scoped>
.omfetrab {
	$pad: 8px;

	display: flex;
	flex-direction: column;

	width: calc((var(--mkep-size) * var(--mkep-width)) + #{$pad * 2});
	height: calc((var(--mkep-size) * var(--mkep-height)) + #{$pad * 2});

	&.s1 {
		--mkep-size: 40px;
	}

	&.s2 {
		--mkep-size: 45px;
	}

	&.s3 {
		--mkep-size: 50px;
	}

	&.w1 {
		--mkep-width: 5;
	}

	&.w2 {
		--mkep-width: 6;
	}

	&.w3 {
		--mkep-width: 7;
	}

	&.w4 {
		--mkep-width: 8;
	}

	&.w5 {
		--mkep-width: 9;
	}

	&.h1 {
		--mkep-height: 4;
	}

	&.h2 {
		--mkep-height: 6;
	}

	&.h3 {
		--mkep-height: 8;
	}

	&.h4 {
		--mkep-height: 10;
	}

	&.asDrawer {
		padding: 0 0 max(env(safe-area-inset-bottom, 0px), 12px) 0;
		width: 100%;
		border-radius: 24px;
		border-bottom-right-radius: 0;
		border-bottom-left-radius: 0;

		> .emojis {
			::v-deep(section) {
				> header {
					height: 32px;
					line-height: 32px;
					padding: 0 12px;
					font-size: 15px;
				}

				> .body {
					display: grid;
					grid-template-columns: repeat(var(--mkep-width), 1fr);
					font-size: 30px;

					> .item {
						aspect-ratio: 1 / 1;
						width: auto;
						height: auto;
						min-width: 0;
					}
				}
			}
		}
	}

	&.asWindow {
		width: 100%;
		height: 100%;

		> .emojis {
			::v-deep(section) {
				> .body {
					display: grid;
					grid-template-columns: repeat(auto-fill, minmax(var(--mkep-size), 1fr));
					font-size: 30px;

					> .item {
						aspect-ratio: 1 / 1;
						width: auto;
						height: auto;
						min-width: 0;
					}
				}
			}
		}
	}

	> .search {
		width: 100%;
		padding: 12px;
		box-sizing: border-box;
		font-size: 1em;
		outline: none;
		border: none;
		background: transparent;
		color: var(--fg);

		&:not(.filled) {
			order: 1;
			z-index: 2;
			box-shadow: 0px -1px 0 0px var(--divider);
		}
	}

	> .emojis {
		height: 100%;
		overflow-y: auto;
		overflow-x: hidden;

		scrollbar-width: none;

		&::-webkit-scrollbar {
			display: none;
		}

		> .group {
			&:not(.index) {
				padding: 4px 0 8px 0;
				border-top: solid 0.5px var(--divider);
			}

			> header {
				/*position: sticky;
				top: 0;
				left: 0;*/
				height: 32px;
				line-height: 32px;
				z-index: 2;
				padding: 0 8px;
				font-size: 12px;
			}
		}

		::v-deep(section) {
			> header {
				position: sticky;
				top: 0;
				left: 0;
				height: 32px;
				line-height: 32px;
				z-index: 1;
				padding: 0 8px;
				font-size: 12px;
				cursor: pointer;

				&:hover {
					color: var(--accent);
				}
			}

			> .body {
				position: relative;
				padding: $pad;

				> .item {
					position: relative;
					padding: 0;
					width: var(--mkep-size);
					height: var(--mkep-size);
					contain: strict;
					border-radius: 4px;
					font-size: 24px;

					&:focus-visible {
						outline: solid 2px var(--focus);
						z-index: 1;
					}

					&:hover {
						background: rgba(0, 0, 0, 0.05);
					}

					&:active {
						background: var(--accent);
						box-shadow: inset 0 0.15em 0.3em rgba(27, 31, 35, 0.15);
					}

					> .emoji {
						height: 1.25em;
						vertical-align: -.25em;
						pointer-events: none;
					}
				}
			}

			&.result {
				border-bottom: solid 0.5px var(--divider);

				&:empty {
					display: none;
				}
			}
		}
	}
}
</style>
