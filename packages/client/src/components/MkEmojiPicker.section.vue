<template>
<!-- このコンポーネントの要素のclassは親から利用されるのでむやみに弄らないこと -->
<section>
	<header class="_acrylic" @click="shown = !shown">
		<i class="toggle ti-fw" :class="shown ? 'ti ti-chevron-down' : 'ti ti-chevron-up'"></i> <slot></slot> ({{ emojis.length }})
	</header>
	<div v-if="shown" class="body">
		<button
			v-for="emoji in emojis"
			:key="emoji"
			:data-emoji="emoji"
			class="_button item"
			@pointerenter="computeButtonTitle"
			@click="emit('chosen', emoji, $event)"
		>
			<MkEmoji class="emoji" :emoji="emoji" :normal="true"/>
		</button>
	</div>
</section>
</template>

<script lang="ts" setup>
import { ref, computed, Ref } from 'vue';
import { getEmojiName } from '@/scripts/emojilist';

const props = defineProps<{
	emojis: string[] | Ref<string[]>;
	initialShown?: boolean;
}>();

const emit = defineEmits<{
	(ev: 'chosen', v: string, event: MouseEvent): void;
}>();

const emojis = computed(() => Array.isArray(props.emojis) ? props.emojis : props.emojis.value);

const shown = ref(!!props.initialShown);

/** @see MkEmojiPicker.vue */
const computeButtonTitle = (ev: MouseEvent): void => {
	const el = ev.target;
	if (!(el instanceof HTMLElement)) return;
	const emoji = el.dataset.emoji;
	if (!emoji) return;
	el.title = emoji.startsWith(':') ? emoji : getEmojiName(emoji) ?? emoji;
};
</script>
