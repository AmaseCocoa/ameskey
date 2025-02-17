<template>
<div
	v-if="!muted"
	v-show="!isDeleted"
	ref="el"
	v-hotkey="keymap"
	v-size="{ max: [500, 450, 350, 300] }"
	class="tkcbzcuz"
	:tabindex="!isDeleted ? '-1' : undefined"
	:class="{ renote: isRenote, showActionsOnlyOnHover }"
>
	<MkNoteSub v-if="appearNote.reply" :note="appearNote.reply" class="reply-to"/>
	<div v-if="pinned" class="info"><i class="ti ti-pin"></i> {{ i18n.ts.pinnedNote }}</div>
	<div v-if="(appearNote as any /* 定義されていないため */)._prId_" class="info"><i class="ti ti-speakerphone"></i> {{ i18n.ts.promotion }}<button class="_textButton hide" @click="readPromo()">{{ i18n.ts.hideThisNote }} <i class="ti ti-x"></i></button></div>
	<div v-if="(appearNote as any /* 定義されていないため */)._featuredId_" class="info"><i class="ti ti-bolt"></i> {{ i18n.ts.featured }}</div>
	<div v-if="isRenote" class="renote">
		<MkAvatar class="avatar" :user="note.user"/>
		<i class="ti ti-repeat"></i>
		<I18n :src="i18n.ts.renotedBy" tag="span">
			<template #user>
				<MkA v-user-preview="note.userId" class="name" :to="userPage(note.user)">
					<MkUserName :user="note.user"/>
				</MkA>
			</template>
		</I18n>
		<div class="info">
			<button ref="renoteTime" class="_button time" @click="showRenoteMenu()">
				<i v-if="isMyRenote" class="ti ti-dots dropdownIcon"></i>
				<MkTime :time="note.createdAt"/>
			</button>
			<MkVisibility :note="note"/>
		</div>
	</div>
	<div v-if="renoteCollapsed" class="collapsed-renote">
		<MkAvatar class="avatar" :user="appearNote.user"/>
		<Mfm :text="getNoteSummary(appearNote)" :plain="true" :nowrap="true" :author="appearNote.user" class="text" @click="renoteCollapsed = false"/>
	</div>
	<article v-else ref="articleEl" class="article" :style="{ '--articleTop': `${(el?.clientHeight ?? 0) - (articleEl?.clientHeight ?? 0)}px` }" @contextmenu.stop="onContextmenu">
		<MkAvatar class="avatar" :user="appearNote.user"/>
		<div class="main">
			<XNoteHeader class="header" :note="appearNote" :mini="true"/>
			<MkInstanceTicker v-if="showTicker" :instance="appearNote.user.instance"/>
			<div class="body">
				<p v-if="appearNote.cw != null" class="cw">
					<Mfm v-if="appearNote.cw != ''" class="text" :text="appearNote.cw" :author="appearNote.user" :i="$i" :custom-emojis="appearNote.emojis"/>
					<XCwButton v-model="showContent" :note="appearNote"/>
				</p>
				<div v-show="appearNote.cw == null || showContent" class="content" :class="{ collapsed, isLong }">
					<div ref="textEl" class="text">
						<span v-if="appearNote.isHidden" style="opacity: 0.5">({{ i18n.ts.private }})</span>
						<MkA v-if="appearNote.replyId" class="reply" :to="`/notes/${appearNote.replyId}`"><i class="ti ti-arrow-back-up"></i></MkA>
						<Mfm v-if="appearNote.text" :text="appearNote.text" :author="appearNote.user" :i="$i" :custom-emojis="appearNote.emojis"/>
						<a v-if="appearNote.renote != null" class="rp">RN:</a>
						<div v-if="translating || translation" class="translation">
							<MkLoading v-if="translating" mini/>
							<div v-else class="translated">
								<b>{{ $t('translatedFrom', { x: (translation as any /* 定義されていないため */).sourceLang }) }}: </b>
								<Mfm :text="(translation as any /* 定義されていないため */).text" :author="appearNote.user" :i="$i" :custom-emojis="appearNote.emojis"/>
							</div>
						</div>
					</div>
					<div v-if="appearNote.files.length > 0" class="files">
						<XMediaList :media-list="appearNote.files"/>
					</div>
					<XPoll v-if="appearNote.poll" ref="pollViewer" :note="appearNote" class="poll"/>
					<MkUrlPreview v-for="url in urls" :key="url" :url="url" :compact="true" :detail="false" class="url-preview"/>
					<div v-if="appearNote.renote" class="renote"><XNoteSimple :note="appearNote.renote"/></div>
					<button v-if="isLong && collapsed" class="fade _button" @click="collapsedFlag = false">
						<span>{{ i18n.ts.showMore }}</span>
					</button>
					<button v-else-if="isLong && !collapsed" class="showLess _button" @click="collapsedFlag = true">
						<span>{{ i18n.ts.showLess }}</span>
					</button>
				</div>
				<MkA v-if="(appearNote as any /* 定義されていないため */).channel && !inChannel" class="channel" :to="`/channels/${(appearNote as any /* 定義されていないため */).channel.id}`"><i class="ti ti-device-tv"></i> {{ (appearNote as any /* 定義されていないため */).channel.name }}</MkA>
			</div>
			<XReactionsViewer ref="reactionsViewer" :note="appearNote"/>
			<footer class="footer">
				<button class="button _button" @click="reply()">
					<i class="ti ti-arrow-back-up"></i>
					<p v-if="appearNote.repliesCount > 0" class="count">{{ appearNote.repliesCount }}</p>
				</button>
				<XRenoteButton ref="renoteButton" class="button" :note="appearNote" :count="appearNote.renoteCount"/>
				<button v-if="appearNote.myReaction == null" ref="reactButton" class="button _button" @click="react()">
					<i class="ti ti-plus"></i>
				</button>
				<button v-if="appearNote.myReaction != null" ref="reactButton" class="button _button reacted" @click="undoReact(appearNote)">
					<i class="ti ti-minus"></i>
				</button>
				<button ref="menuButton" class="button _button" @click="menu()">
					<i class="ti ti-dots"></i>
				</button>
				<MkA v-if="showActionsOnlyOnHover" class="button _button" style="text-decoration: none;" :to="notePage(appearNote)">
					<i class="ti ti-info-circle"></i>
				</MkA>
			</footer>
		</div>
	</article>
</div>
<div v-else class="muted" @click="muted = false">
	<I18n :src="i18n.ts.userSaysSomething" tag="small">
		<template #name>
			<MkA v-user-preview="appearNote.userId" class="name" :to="userPage(appearNote.user)">
				<MkUserName :nowrap="false" :user="appearNote.user"/>
			</MkA>
		</template>
	</I18n>
</div>
</template>

<script lang="ts" setup>
import { inject, onMounted, ref, Ref, computed } from 'vue';
import { ReactiveVariable } from 'vue/macros';
import * as mfm from 'mfm-js';
import * as misskey from 'misskey-js';
import MkNoteSub from '@/components/MkNoteSub.vue';
import XNoteHeader from '@/components/MkNoteHeader.vue';
import XNoteSimple from '@/components/MkNoteSimple.vue';
import XReactionsViewer from '@/components/MkReactionsViewer.vue';
import XMediaList from '@/components/MkMediaList.vue';
import XCwButton from '@/components/MkCwButton.vue';
import XPoll from '@/components/MkPoll.vue';
import XRenoteButton from '@/components/MkRenoteButton.vue';
import MkUrlPreview from '@/components/MkUrlPreview.vue';
import MkInstanceTicker from '@/components/MkInstanceTicker.vue';
import MkVisibility from '@/components/MkVisibility.vue';
import { pleaseLogin } from '@/scripts/please-login';
import { focusPrev, focusNext } from '@/scripts/focus';
import { checkWordMute } from '@/scripts/check-word-mute';
import { notePage } from '@/filters/note';
import { userPage } from '@/filters/user';
import * as os from '@/os';
import { defaultStore, noteViewInterruptors } from '@/store';
import { reactionPicker } from '@/scripts/reaction-picker';
import { extractUrlFromMfm } from '@/scripts/extract-url-from-mfm';
import { $i } from '@/account';
import { i18n } from '@/i18n';
import { getNoteMenu } from '@/scripts/get-note-menu';
import { useNoteCapture } from '@/scripts/use-note-capture';
import { getNoteSummary } from '@/scripts/get-note-summary';
import { deepClone } from '@/scripts/clone';
import { isTouchUsing, disableContextmenu } from '@/scripts/touch';
import { deviceKind } from '@/scripts/device-kind';
import { shownNoteIds } from '@/os';
import { tmsStore } from '@/tms/store';
import { isPureRenote } from '@/scripts/tms/is-pure-renote';

const props = defineProps<{
	note: misskey.entities.Note;
	pinned?: boolean;
}>();

const inChannel = inject('inChannel', null);

let note = $ref<misskey.entities.Note>(deepClone(props.note));

// plugin
if (noteViewInterruptors.length > 0) {
	onMounted(async () => {
		let result = deepClone(note);
		for (const interruptor of noteViewInterruptors) {
			result = await interruptor.handler(result) as ReactiveVariable<misskey.entities.Note>; // unknownのため
		}
		note = result;
	});
}

const isRenote = isPureRenote(note);

const textEl = ref<HTMLElement>();
let textElHeight = $ref<number | null>(null);
onMounted(() => {
	if (textEl.value) {
		const resizeObserver = new ResizeObserver(() => {
			textElHeight = textEl.value?.offsetHeight ?? 0;
		});
		resizeObserver.observe(textEl.value);
	}
});

const el = ref<HTMLElement>();
const articleEl = ref<HTMLElement>();
const menuButton = ref<HTMLElement>();
const renoteButton = ref<InstanceType<typeof XRenoteButton>>();
const renoteTime = ref<HTMLElement>();
const reactButton = ref<HTMLElement>();
let appearNote = $computed(() => isPureRenote(note) ? note.renote : note); // 本当はisRenoteを使いたいけど型推論してくれない
const isMyRenote = $i && ($i.id === note.userId || $i.isModerator || $i.isAdmin);
const showContent = ref(false);
const urls = appearNote.text ? extractUrlFromMfm(mfm.parse(appearNote.text)) : null;
const { collapseNote, collapseNoteHeight, collapseNoteFile, collapseNoteUrl, collapseNotePoll } = tmsStore.state;
const isLong = $computed(() => {
	return collapseNote && !!(
		appearNote.cw == null && 
		appearNote.text != null && (
			// textElHeight: null の場合は文字数で判定する
			(!!collapseNoteHeight && (textElHeight == null ? appearNote.text.length > 500 : textElHeight >= collapseNoteHeight)) ||
			(!!collapseNoteFile && (appearNote.files.length >= collapseNoteFile)) ||
			(!!collapseNoteUrl && (urls && urls.length >= collapseNoteUrl)) ||
			(!!collapseNotePoll && (appearNote.poll?.choices.length ?? 0) >= collapseNotePoll)
		)
	);
});
const collapsedFlag = ref(true);
const collapsed = $computed(() => collapsedFlag.value && isLong);
const isDeleted = ref(false);
const muted = ref(checkWordMute(appearNote, $i, defaultStore.state.mutedWords));
const translation = ref(null);
const translating = ref(false);
const showTicker = defaultStore.state.instanceTicker === 'always' || (defaultStore.state.instanceTicker === 'remote' && appearNote.user.instance);
const showActionsOnlyOnHover = computed(() => tmsStore.state.showActionsOnlyOnHover && !isTouchUsing && deviceKind !== 'smartphone');
let renoteCollapsed = $ref(tmsStore.state.collapseRenote && isRenote && (($i && $i.id === note.userId) || shownNoteIds.has(appearNote.id)));
shownNoteIds.add(appearNote.id);

const keymap = {
	'r': (): void => reply(true),
	'e|a|plus': (): void => react(true),
	'q': (): void => renoteButton.value?.renote(true),
	'up|k|shift+tab': (): void => focusBefore(),
	'down|j|tab': (): void => focusAfter(),
	'esc': (): void => blur(),
	'm|o': (): void => menu(true),
};

useNoteCapture({
	rootEl: el as Ref<HTMLElement>, // undefinedを除外するため
	note: $$(appearNote),
	isDeletedRef: isDeleted,
});

const reply = (viaKeyboard = false): void => {
	pleaseLogin();
	os.post({
		reply: appearNote,
		animation: !viaKeyboard,
	});
};

const react = (_viaKeyboard = false): void => {
	if (!reactButton.value) return;

	pleaseLogin();
	blur();
	reactionPicker.show(reactButton.value, reaction => {
		os.api('notes/reactions/create', {
			noteId: appearNote.id,
			reaction: reaction,
		});
	}, focus);
};

const undoReact = (note_: misskey.entities.Note): void => {
	const oldReaction = note_.myReaction;
	if (!oldReaction) return;
	os.api('notes/reactions/delete', {
		noteId: note_.id,
	});
};

const currentClipPage = inject<Ref<misskey.entities.Clip> | null>('currentClipPage', null);

const onContextmenu = (ev: MouseEvent): void => {
	if (disableContextmenu) return;
	const isLink = (elem: HTMLElement): boolean => {
		if (elem.tagName === 'A') return true;
		if (elem.parentElement) {
			return isLink(elem.parentElement);
		}

		return false;
	};
	if (!(ev.target instanceof HTMLElement)) return;
	if (isLink(ev.target)) return;
	if (window.getSelection()?.toString() !== '') return;

	if (defaultStore.state.useReactionPickerForContextMenu) {
		ev.preventDefault();
		react();
	} else {
		os.contextMenu(
			getNoteMenu({
				note,
				translating,
				translation,
				// menuButton,
				isDeleted,
				currentClipPage: currentClipPage ?? undefined,
			}),
			ev,
		).then(focus);
	}
};

const menu = (viaKeyboard = false): void => {
	os.popupMenu(
		getNoteMenu({
			note,
			translating,
			translation,
			// menuButton,
			isDeleted,
			currentClipPage: currentClipPage ?? undefined,
		}),
		menuButton.value,
		{ viaKeyboard },
	).then(focus);
};

const showRenoteMenu = (viaKeyboard = false): void => {
	if (!isMyRenote) return;
	os.popupMenu([{
		text: i18n.ts.unrenote,
		icon: 'ti ti-trash',
		danger: true,
		action: (): void => {
			os.api('notes/delete', {
				noteId: note.id,
			});
			isDeleted.value = true;
		},
	}], renoteTime.value, {
		viaKeyboard: viaKeyboard,
	});
};

const focus = (): void => {
	el.value?.focus();
};

const blur = (): void => {
	el.value?.blur();
};

const focusBefore = (): void => {
	if (el.value) focusPrev(el.value);
};

const focusAfter = (): void => {
	if (el.value) focusNext(el.value);
};

const readPromo = (): void => {
	os.api('promo/read', {
		noteId: appearNote.id,
	});
	isDeleted.value = true;
};
</script>

<style lang="scss" scoped>
.tkcbzcuz {
	position: relative;
	transition: box-shadow 0.1s ease;
	font-size: 1.05em;
	overflow: clip;
	contain: content;

	// これらの指定はパフォーマンス向上には有効だが、ノートの高さは一定でないため、
	// 下の方までスクロールすると上のノートの高さがここで決め打ちされたものに変化し、表示しているノートの位置が変わってしまう
	// ノートがマウントされたときに自身の高さを取得し contain-intrinsic-size を設定しなおせばほぼ解決できそうだが、
	// 今度はその処理自体がパフォーマンス低下の原因にならないか懸念される。また、被リアクションでも高さは変化するため、やはり多少のズレは生じる
	// 一度レンダリングされた要素はブラウザがよしなにサイズを覚えておいてくれるような実装になるまで待った方が良さそう(なるのか？)
	//content-visibility: auto;
	//contain-intrinsic-size: 0 128px;

	&:focus-visible {
		outline: none;

		&:after {
			content: "";
			pointer-events: none;
			display: block;
			position: absolute;
			z-index: 10;
			top: 0;
			left: 0;
			right: 0;
			bottom: 0;
			margin: auto;
			width: calc(100% - 8px);
			height: calc(100% - 8px);
			border: dashed 1px var(--focus);
			border-radius: var(--radius);
			box-sizing: border-box;
		}
	}

	&:hover > .article > .main > .footer > .button {
		opacity: 1;
	}

	&.showActionsOnlyOnHover {
		> .article > .main > .footer {
			visibility: hidden;
			position: absolute;
			top: calc(12px + var(--articleTop, 0px));
			right: 12px;
			padding: 0 4px;
			margin-bottom: 0 !important;
			background: var(--popup);
			border-radius: 8px;
			box-shadow: 0px 4px 32px var(--shadow);

			> .button {
				font-size: 80%;

				&:not(:last-child) {
					margin-right: 6px !important;
				}
			}
		}

		&:hover {
			> .article > .main > .footer {
				visibility: visible;
			}
		}
	}

	> .info {
		display: flex;
		align-items: center;
		padding: 16px 32px 8px 32px;
		line-height: 24px;
		font-size: 90%;
		white-space: pre;
		color: #d28a3f;

		> i {
			margin-right: 4px;
		}

		> .hide {
			margin-left: auto;
			color: inherit;
		}
	}

	> .info + .article {
		padding-top: 8px;
	}

	> .reply-to {
		opacity: 0.7;
		padding-bottom: 0;
	}

	> .renote {
		display: flex;
		align-items: center;
		padding: 16px 32px 8px 32px;
		line-height: 28px;
		white-space: pre;
		color: var(--renote);

		> .avatar {
			flex-shrink: 0;
			display: inline-block;
			width: 28px;
			height: 28px;
			margin: 0 8px 0 0;
		}

		> i {
			margin-right: 4px;
		}

		> span {
			overflow: hidden;
			flex-shrink: 1;
			text-overflow: ellipsis;
			white-space: nowrap;

			> .name {
				font-weight: bold;
			}
		}

		> .info {
			margin-left: auto;
			font-size: 0.9em;

			> .time {
				flex-shrink: 0;
				color: inherit;

				> .dropdownIcon {
					margin-right: 4px;
				}
			}
		}
	}

	> .renote + .article {
		padding-top: 8px;
	}

	> .collapsed-renote {
		display: flex;
		align-items: center;
		line-height: 28px;
		white-space: pre;
		padding: 0 32px 18px;

		> .avatar {
			flex-shrink: 0;
			display: inline-block;
			width: 28px;
			height: 28px;
			margin: 0 8px 0 0;
		}

		> .text {
			overflow: hidden;
			flex-shrink: 1;
			text-overflow: ellipsis;
			white-space: nowrap;
			font-size: 90%;
			opacity: 0.7;
			cursor: pointer;

			&:hover {
				text-decoration: underline;
			}
		}
	}

	> .article {
		display: flex;
		padding: 28px 32px 18px;

		> .avatar {
			flex-shrink: 0;
			display: block;
			margin: 0 14px 8px 0;
			width: 58px;
			height: 58px;
			position: sticky;
			top: calc(22px + var(--stickyTop, 0px));
			left: 0;
		}

		> .main {
			flex: 1;
			min-width: 0;

			> .body {
				> .cw {
					cursor: default;
					display: block;
					margin: 0;
					padding: 0;
					overflow-wrap: break-word;

					> .text {
						margin-right: 8px;
					}
				}

				> .content {
					&.isLong {
						> .showLess {
							display: block;
							position: sticky;
							z-index: 1;
							bottom: var(--minBottomSpacing);
							left: 0;
							width: 100%;
							height: 64px;

							> span {
								display: inline-block;
								background: var(--popup);
								padding: 6px 10px;
								font-size: 0.8em;
								border-radius: 999px;
								box-shadow: 0 2px 6px rgb(0 0 0 / 20%);
							}
						}
					}

					&.collapsed {
						position: relative;
						max-height: 9em;
						overflow: hidden;

						> .fade {
							display: block;
							position: absolute;
							z-index: 1;
							bottom: 0;
							left: 0;
							width: 100%;
							height: 64px;
							background: linear-gradient(0deg, var(--panel), var(--X15));

							> span {
								display: inline-block;
								background: var(--panel);
								padding: 6px 10px;
								font-size: 0.8em;
								border-radius: 999px;
								box-shadow: 0 2px 6px rgb(0 0 0 / 20%);
							}

							&:hover {
								> span {
									background: var(--panelHighlight);
								}
							}
						}
					}

					> .text {
						overflow-wrap: break-word;

						> .reply {
							color: var(--accent);
							margin-right: 0.5em;
						}

						> .rp {
							margin-left: 4px;
							font-style: oblique;
							color: var(--renote);
						}

						> .translation {
							border: solid 0.5px var(--divider);
							border-radius: var(--radius);
							padding: 12px;
							margin-top: 8px;
						}
					}

					> .url-preview {
						margin-top: 8px;
					}

					> .poll {
						font-size: 80%;
					}

					> .renote {
						padding: 8px 0;

						> * {
							padding: 16px;
							border: dashed 1px var(--renote);
							border-radius: 8px;
						}
					}
				}

				> .channel {
					opacity: 0.7;
					font-size: 80%;
				}
			}

			> .footer {
				> .button {
					margin: 0;
					padding: 8px;
					opacity: 0.7;

					&:not(:last-child) {
						margin-right: 28px;
					}

					&:hover {
						color: var(--fgHighlighted);
					}

					> .count {
						display: inline;
						margin: 0 0 0 8px;
						opacity: 0.7;
					}

					&.reacted {
						color: var(--accent);
					}
				}
			}
		}
	}

	> .reply {
		border-top: solid 0.5px var(--divider);
	}

	&.max-width_500px {
		font-size: 0.9em;

		> .article {
			> .avatar {
				width: 50px;
				height: 50px;
			}
		}
	}

	&.max-width_450px {
		> .renote {
			padding: 8px 16px 0 16px;
		}

		> .info {
			padding: 8px 16px 0 16px;
		}

		> .collapsed-renote {
			padding: 0 16px 9px;
			margin-top: 4px;
		}

		> .article {
			padding: 14px 16px 9px;

			> .avatar {
				margin: 0 10px 8px 0;
				width: 46px;
				height: 46px;
				top: calc(14px + var(--stickyTop, 0px));
			}
		}
	}

	&.max-width_350px {
		> .article {
			> .main {
				> .footer {
					> .button {
						&:not(:last-child) {
							margin-right: 18px;
						}
					}
				}
			}
		}
	}

	&.max-width_300px {
		> .article {
			> .avatar {
				width: 44px;
				height: 44px;
			}

			> .main {
				> .footer {
					> .button {
						&:not(:last-child) {
							margin-right: 12px;
						}
					}
				}
			}
		}
	}
}

.muted {
	padding: 8px;
	text-align: center;
	opacity: 0.7;
}
</style>
