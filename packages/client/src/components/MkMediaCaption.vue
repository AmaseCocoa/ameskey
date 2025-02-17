<template>
<MkModal ref="modal" @click="done(true)" @closed="$emit('closed')">
	<div class="container">
		<div class="fullwidth top-caption">
			<div class="mk-dialog">
				<header>
					<Mfm v-if="title" class="title" :text="title"/>
					<span class="text-count" :class="{ over: remainingLength < 0 }">{{ remainingLength }}</span>
				</header>
				<textarea v-model="inputValue" autofocus :placeholder="input.placeholder" @keydown="onInputKeydown"></textarea>
				<div v-if="(showOkButton || showCancelButton)" class="buttons">
					<MkButton inline primary :disabled="remainingLength < 0" @click="ok">{{ $ts.ok }}</MkButton>
					<MkButton inline @click="cancel">{{ $ts.cancel }}</MkButton>
				</div>
			</div>
		</div>
		<div class="hdrwpsaf fullwidth">
			<header>{{ image.name }}</header>
			<img :src="image.url" :alt="image.comment" :title="image.comment" @click="$refs.modal.close()"/>
			<footer>
				<span>{{ image.type }}</span>
				<span>{{ bytes(image.size) }}</span>
				<span v-if="image.properties && image.properties.width">{{ number(image.properties.width) }}px × {{ number(image.properties.height) }}px</span>
			</footer>
		</div>
	</div>
</MkModal>
</template>

<script lang="ts">
import { defineComponent } from 'vue';
import { length } from 'stringz';
import MkModal from '@/components/MkModal.vue';
import MkButton from '@/components/MkButton.vue';
import bytes from '@/filters/bytes';
import number from '@/filters/number';

export default defineComponent({
	components: {
		MkModal,
		MkButton,
	},

	props: {
		image: {
			type: Object,
			required: true,
		},
		title: {
			type: String,
			required: false,
			default: undefined,
		},
		input: {
			type: Object,
			required: true,
		},
		showOkButton: {
			type: Boolean,
			default: true,
		},
		showCancelButton: {
			type: Boolean,
			default: true,
		},
		cancelableByBgClick: {
			type: Boolean,
			default: true,
		},
	},

	emits: ['done', 'closed'],

	data() {
		return {
			inputValue: this.input.default ? this.input.default : null,
		};
	},

	computed: {
		remainingLength(): number {
			if (typeof this.inputValue !== 'string') return 512;
			return 512 - length(this.inputValue);
		},
	},

	mounted() {
		document.addEventListener('keydown', this.onKeydown);
	},

	beforeUnmount() {
		document.removeEventListener('keydown', this.onKeydown);
	},

	methods: {
		bytes,
		number,

		done(canceled: boolean, result?) {
			this.$emit('done', { canceled, result });
			this.$refs.modal.close();
		},

		async ok() {
			if (!this.showOkButton) return;

			const result = this.inputValue;
			this.done(false, result);
		},

		cancel() {
			this.done(true);
		},

		onBgClick() {
			if (this.cancelableByBgClick) {
				this.cancel();
			}
		},

		onKeydown(evt: KeyboardEvent) {
			if (evt.key === 'Escape' || evt.key === 'Esc') {
				this.cancel();
			}
		},

		onInputKeydown(evt: KeyboardEvent) {
			if (evt.key === 'Enter') {
				if (evt.ctrlKey) {
					evt.preventDefault();
					evt.stopPropagation();
					this.ok();
				}
			}
		},
	},
});
</script>

<style lang="scss" scoped>
.container {
	display: flex;
	width: 100%;
	height: 100%;
	flex-direction: row;
	overflow: scroll;
	position: fixed;
	left: 0;
	top: 0;
}
@media (max-width: 850px) {
	.container {
		flex-direction: column;
	}
	.top-caption {
		padding-bottom: 8px;
	}
}
.fullwidth {
	width: 100%;
	margin: auto;
}
.mk-dialog {
	position: relative;
	padding: 32px;
	min-width: 320px;
	max-width: 480px;
	box-sizing: border-box;
	text-align: center;
	background: var(--panel);
	border-radius: var(--radius);
	margin: auto;

	> header {
		margin: 0 0 8px 0;
		position: relative;

		> .title {
			font-weight: bold;
			font-size: 20px;
		}

		> .text-count {
			opacity: 0.7;
			position: absolute;
			right: 0;
		}
	}

	> .buttons {
		margin-top: 16px;

		> * {
			margin: 0 8px;
		}
	}

	> textarea {
		display: block;
		box-sizing: border-box;
		padding: 0 24px;
		margin: 0;
		width: 100%;
		font-size: 16px;
		border: none;
		border-radius: 0;
		background: transparent;
		color: var(--fg);
		font-family: inherit;
		max-width: 100%;
		min-width: 100%;
		min-height: 90px;

		&:focus-visible {
			outline: none;
		}

		&:disabled {
			opacity: 0.5;
		}
	}
}
.hdrwpsaf {
	display: flex;
	flex-direction: column;
	height: 100%;

	> header,
	> footer {
		align-self: center;
		display: inline-block;
		padding: 6px 9px;
		font-size: 90%;
		background: rgba(0, 0, 0, 0.5);
		border-radius: 6px;
		color: #fff;
	}

	> header {
		margin-bottom: 8px;
		opacity: 0.9;
	}

	> img {
		display: block;
		flex: 1;
		min-height: 0;
		object-fit: contain;
		width: 100%;
		cursor: zoom-out;
		image-orientation: from-image;
	}

	> footer {
		margin-top: 8px;
		opacity: 0.8;

		> span + span {
			margin-left: 0.5em;
			padding-left: 0.5em;
			border-left: solid 1px rgba(255, 255, 255, 0.5);
		}
	}
}
</style>
