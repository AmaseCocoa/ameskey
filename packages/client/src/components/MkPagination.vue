<template>
<Transition
	mode="out-in"
	:enter-active-class="defaultStore.state.animation ? $style.transition_fade_enterActive : ''"
	:leave-active-class="defaultStore.state.animation ? $style.transition_fade_leaveActive : ''"
	:enter-from-class="defaultStore.state.animation ? $style.transition_fade_enterFrom : ''"
	:leave-to-class="defaultStore.state.animation ? $style.transition_fade_leaveTo : ''"
>
	<MkLoading v-if="fetching"/>

	<MkError v-else-if="error" @retry="init()"/>

	<div v-else-if="empty" key="_empty_" class="empty">
		<slot name="empty">
			<div class="_fullinfo">
				<img src="https://xn--931a.moe/assets/info.jpg" class="_ghost"/>
				<div>{{ i18n.ts.nothing }}</div>
			</div>
		</slot>
	</div>

	<div v-else ref="rootEl">
		<div v-show="pagination.reversed && more" key="_more_ahead_" class="_gap" :class="$style.loadMore">
			<MkButton
				v-if="!moreFetching"
				v-appear="(enableInfiniteScroll && !props.disableAutoLoad) ? fetchMoreAhead : null"
				:disabled="moreFetching"
				:style="{ cursor: moreFetching ? 'wait' : 'pointer' }"
				primary
				rounded
				@click="fetchMoreAhead"
			>
				{{ i18n.ts.loadMore }}
			</MkButton>
			<MkLoading v-else class="loading"/>
		</div>
		<slot :items="items" :users="users" :fetching="fetching || moreFetching"></slot>
		<div v-show="!pagination.reversed && more" key="_more_behind_" class="_gap" :class="$style.loadMore">
			<MkButton
				v-if="!moreFetching"
				v-appear="(enableInfiniteScroll && !props.disableAutoLoad) ? fetchMore : null"
				:disabled="moreFetching"
				:style="{ cursor: moreFetching ? 'wait' : 'pointer' }"
				primary
				rounded
				@click="fetchMore"
			>
				{{ i18n.ts.loadMore }}
			</MkButton>
			<MkLoading v-else class="loading"/>
		</div>
	</div>
</Transition>
</template>

<script lang="ts" setup>
import { computed, ComputedRef, isRef, nextTick, onActivated, onBeforeUnmount, onDeactivated, onMounted, ref, watch, unref } from 'vue';
import * as misskey from 'misskey-js';
import * as os from '@/os';
import { onScrollTop, isTopVisible, getBodyScrollHeight, getScrollContainer, onScrollBottom, scrollToBottom, scroll, isBottomVisible } from '@/scripts/scroll';
import { useDocumentVisibility } from '@/scripts/use-document-visibility';
import MkButton from '@/components/MkButton.vue';
import { defaultStore } from '@/store';
import { MisskeyEntity } from '@/types/date-separated-list';
import { i18n } from '@/i18n';

export type Paging<E extends keyof misskey.Endpoints = keyof misskey.Endpoints> = {
	endpoint: E;
	limit: number;
	params?: misskey.Endpoints[E]['req'] | ComputedRef<misskey.Endpoints[E]['req']>;

	/**
	 * 検索APIのような、ページング不可なエンドポイントを利用する場合
	 * (そのようなAPIをこの関数で使うのは若干矛盾してるけど)
	 */
	noPaging?: boolean;

	/**
	 * items 配列の中身を逆順にする(新しい方が最後)
	 */
	reversed?: boolean;

	offsetMode?: boolean;

	pageEl?: HTMLElement;
};

const SECOND_FETCH_LIMIT = 30;
const TOLERANCE = 16;

const props = withDefaults(defineProps<{
	pagination: Paging;
	disableAutoLoad?: boolean;
	displayLimit?: number;
}>(), {
	displayLimit: 20,
});

const emit = defineEmits<{
	(ev: 'queue', count: number): void;
}>();

let rootEl = $shallowRef<HTMLElement>();

// 遡り中かどうか
let backed = $ref(false);

let scrollRemove = $ref<(() => void) | null>(null);

const items = ref<MisskeyEntity[]>([]);
const users = computed(() => {
	return items.value
		.flatMap(x => {
			const xTyped = x as typeof x & {
				user?: misskey.entities.UserDetailed | null; /* any型のため */
			};
			return xTyped.user ? [xTyped.user] : [];
		})
		.filter((a, i, s) => s.findIndex(b => b.id === a.id) === i);
});
const queue = ref<MisskeyEntity[]>([]);
const offset = ref(0);
const fetching = ref(true);
const moreFetching = ref(false);
const more = ref(false);
const isBackTop = ref(false);
const empty = computed(() => items.value.length === 0);
const error = ref(false);
const {
	enableInfiniteScroll,
} = defaultStore.reactiveState;

const contentEl = $computed(() => props.pagination.pageEl ?? rootEl);
const scrollableElement = $computed(() => getScrollContainer(contentEl ?? null));

const visibility = useDocumentVisibility();

let isPausingUpdate = false;
let timerForSetPause: number | null = null;
const BACKGROUND_PAUSE_WAIT_SEC = 10;

// 先頭が表示されているかどうかを検出
// https://qiita.com/mkataigi/items/0154aefd2223ce23398e
let scrollObserver = $ref<IntersectionObserver>();

watch([(): boolean | undefined => props.pagination.reversed, $$(scrollableElement)], () => {
	if (scrollObserver) scrollObserver.disconnect();

	scrollObserver = new IntersectionObserver(entries => {
		backed = entries[0].isIntersecting;
	}, {
		root: scrollableElement,
		rootMargin: props.pagination.reversed ? '-100% 0px 100% 0px' : '100% 0px -100% 0px',
		threshold: 0.01,
	});
}, { immediate: true });

watch($$(rootEl), () => {
	scrollObserver?.disconnect();
	nextTick(() => {
		if (rootEl) scrollObserver?.observe(rootEl);
	});
});

watch([$$(backed), $$(contentEl)], () => {
	if (!backed) {
		if (!contentEl) return;

		scrollRemove = (props.pagination.reversed ? onScrollBottom : onScrollTop)(contentEl, executeQueue, TOLERANCE);
	} else {
		if (scrollRemove) scrollRemove();
		scrollRemove = null;
	}
});

const init = async (): Promise<void> => {
	queue.value = [];
	fetching.value = true;
	const params = unref(props.pagination.params);
	await os.api(props.pagination.endpoint, {
		...params,
		limit: props.pagination.noPaging ? (props.pagination.limit || 10) : (props.pagination.limit || 10) + 1,
	}).then(res => {
		for (let i = 0; i < res.length; i++) {
			const item = res[i];
			if (i === 3) item._shouldInsertAd_ = true;
		}
		if (!props.pagination.noPaging && (res.length > (props.pagination.limit || 10))) {
			res.pop();
			if (props.pagination.reversed) moreFetching.value = true;
			items.value = res;
			more.value = true;
		} else {
			items.value = res;
			more.value = false;
		}
		offset.value = res.length;
		error.value = false;
		fetching.value = false;
	}, () => {
		error.value = true;
		fetching.value = false;
	});
};

if (props.pagination.params && isRef(props.pagination.params)) {
	watch(props.pagination.params, init, { deep: true });
}

watch(queue, (a, b) => {
	if (a.length === 0 && b.length === 0) return;
	emit('queue', queue.value.length);
}, { deep: true });

const reload = (): Promise<void> => {
	items.value = [];
	return init();
};

const fetchMore = async (): Promise<void> => {
	if (!more.value || fetching.value || moreFetching.value || items.value.length === 0) return;
	moreFetching.value = true;
	const params = unref(props.pagination.params);
	await os.api(props.pagination.endpoint, {
		...params,
		limit: SECOND_FETCH_LIMIT + 1,
		...(props.pagination.offsetMode ? {
			offset: offset.value,
		} : {
			untilId: items.value[items.value.length - 1].id,
		}),
	}).then(res => {
		for (let i = 0; i < res.length; i++) {
			const item = res[i];
			if (i === 10) item._shouldInsertAd_ = true;
		}

		const reverseConcat = (_res): Promise<void> => {
			const oldHeight = scrollableElement ? scrollableElement.scrollHeight : getBodyScrollHeight();
			const oldScroll = scrollableElement ? scrollableElement.scrollTop : window.scrollY;

			items.value = items.value.concat(_res);

			return nextTick(() => {
				if (scrollableElement) {
					scroll(scrollableElement, { top: oldScroll + (scrollableElement.scrollHeight - oldHeight), behavior: 'instant' as ScrollBehavior });
				} else {
					window.scroll({ top: oldScroll + (getBodyScrollHeight() - oldHeight), behavior: 'instant' as ScrollBehavior });
				}

				return nextTick();
			});
		};

		if (res.length > SECOND_FETCH_LIMIT) {
			res.pop();

			if (props.pagination.reversed) {
				reverseConcat(res).then(() => {
					more.value = true;
					moreFetching.value = false;
				});
			} else {
				items.value = items.value.concat(res);
				more.value = true;
				moreFetching.value = false;
			}
		} else {
			if (props.pagination.reversed) {
				reverseConcat(res).then(() => {
					more.value = false;
					moreFetching.value = false;
				});
			} else {
				items.value = items.value.concat(res);
				more.value = false;
				moreFetching.value = false;
			}
		}
		offset.value += res.length;
	}, () => {
		moreFetching.value = false;
	});
};

const fetchMoreAhead = async (): Promise<void> => {
	if (!more.value || fetching.value || moreFetching.value || items.value.length === 0) return;
	moreFetching.value = true;
	const params = unref(props.pagination.params);
	await os.api(props.pagination.endpoint, {
		...params,
		limit: SECOND_FETCH_LIMIT + 1,
		...(props.pagination.offsetMode ? {
			offset: offset.value,
		} : {
			sinceId: items.value[items.value.length - 1].id,
		}),
	}).then(res => {
		if (res.length > SECOND_FETCH_LIMIT) {
			res.pop();
			items.value = items.value.concat(res);
			more.value = true;
		} else {
			items.value = items.value.concat(res);
			more.value = false;
		}
		offset.value += res.length;
		moreFetching.value = false;
	}, () => {
		moreFetching.value = false;
	});
};

const isTop = (): boolean => {
	if (!contentEl) return false;
	return isBackTop.value || (props.pagination.reversed ? isBottomVisible : isTopVisible)(contentEl, TOLERANCE);
};

watch(visibility, () => {
	if (visibility.value === 'hidden') {
		timerForSetPause = window.setTimeout(() => {
			isPausingUpdate = true;
			timerForSetPause = null;
		},
		BACKGROUND_PAUSE_WAIT_SEC * 1000);
	} else { // 'visible'
		if (timerForSetPause) {
			clearTimeout(timerForSetPause);
			timerForSetPause = null;
		} else {
			isPausingUpdate = false;
			if (isTop()) {
				executeQueue();
			}
		}
	}
});

const prepend = (item: MisskeyEntity): void => {
	// 初回表示時はunshiftだけでOK
	if (!rootEl) {
		items.value.unshift(item);
		return;
	}

	if (isTop() && !isPausingUpdate) unshiftItems([item]);
	else prependQueue(item);
};

const unshiftItems = (newItems: MisskeyEntity[]): void => {
	const length = newItems.length + items.value.length;
	items.value = [...newItems, ...items.value].slice(0, props.displayLimit);

	if (length >= props.displayLimit) more.value = true;
};

const executeQueue = (): void => {
	if (queue.value.length === 0) return;
	unshiftItems(queue.value);
	queue.value = [];
};

const prependQueue = (newItem: MisskeyEntity): void => {
	queue.value.unshift(newItem);
	if (queue.value.length >= props.displayLimit) {
		queue.value.pop();
	}
};

const appendItem = (item: MisskeyEntity): void => {
	items.value.push(item);
};

const removeItem = (finder: (item: MisskeyEntity) => boolean): void => {
	const i = items.value.findIndex(finder);
	items.value.splice(i, 1);
};

const updateItem = (id: MisskeyEntity['id'], replacer: (old: MisskeyEntity) => MisskeyEntity): void => {
	const i = items.value.findIndex(item => item.id === id);
	items.value[i] = replacer(items.value[i]);
};

const inited = init();

onActivated(() => {
	isBackTop.value = false;
});

onDeactivated(() => {
	isBackTop.value = props.pagination.reversed ? window.scrollY >= (rootEl ? rootEl.scrollHeight - window.innerHeight : 0) : window.scrollY === 0;
});

const toBottom = (): void => {
	if (contentEl) scrollToBottom(contentEl);
};

onMounted(() => {
	inited.then(() => {
		if (props.pagination.reversed) {
			nextTick(() => {
				setTimeout(toBottom, 800);

				// scrollToBottomでmoreFetchingボタンが画面外まで出るまで
				// more = trueを遅らせる
				setTimeout(() => {
					moreFetching.value = false;
				}, 2000);
			});
		}
	});
});

onBeforeUnmount(() => {
	if (timerForSetPause) {
		clearTimeout(timerForSetPause);
		timerForSetPause = null;
	}
	scrollObserver?.disconnect();
});

defineExpose({
	items,
	queue,
	backed,
	more,
	inited,
	reload,
	prepend,
	append: appendItem,
	removeItem,
	updateItem,
});
</script>

<style lang="scss" module>
.transition_fade_enterActive, .transition_fade_leaveActive {
	transition: opacity 0.125s ease;
}

.transition_fade_enterFrom, .transition_fade_leaveTo {
	opacity: 0;
}

.loadMore {
	display: grid;
	place-items: center;
}
</style>
