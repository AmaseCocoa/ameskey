<template>
<XModalWindow
	ref="dialog"
	:width="450"
	:can-close="false"
	:with-ok-button="true"
	:ok-button-disabled="false"
	@click="cancel()"
	@ok="ok()"
	@close="cancel()"
	@closed="$emit('closed')"
>
	<template #header>
		{{ title }}
	</template>

	<MkSpacer :margin-min="20" :margin-max="32">
		<div class="xkpnjxcv _formRoot">
			<template v-for="item in Object.keys(form).filter(item => !form[item].hidden)" :key="item">
				<FormInput v-if="form[item].type === 'number'" v-model="values[item]" type="number" :step="form[item].step || 1" class="_formBlock">
					<template #label><span v-text="form[item].label || item"></span><span v-if="form[item].required === false"> ({{ $ts.optional }})</span></template>
					<template v-if="form[item].description" #caption>{{ form[item].description }}</template>
				</FormInput>
				<FormInput v-else-if="form[item].type === 'string' && !form[item].multiline" v-model="values[item]" :max="form[item].max" type="text" class="_formBlock">
					<template #label><span v-text="form[item].label || item"></span><span v-if="form[item].required === false"> ({{ $ts.optional }})</span></template>
					<template v-if="form[item].description" #caption>{{ form[item].description }}</template>
				</FormInput>
				<FormTextarea v-else-if="form[item].type === 'string' && form[item].multiline" v-model="values[item]" :max="form[item].max" class="_formBlock">
					<template #label><span v-text="form[item].label || item"></span><span v-if="form[item].required === false"> ({{ $ts.optional }})</span></template>
					<template v-if="form[item].description" #caption>{{ form[item].description }}</template>
				</FormTextarea>
				<FormSwitch v-else-if="form[item].type === 'boolean'" v-model="values[item]" class="_formBlock">
					<span v-text="form[item].label || item"></span>
					<template v-if="form[item].description" #caption>{{ form[item].description }}</template>
				</FormSwitch>
				<FormSelect v-else-if="form[item].type === 'enum'" v-model="values[item]" class="_formBlock">
					<template #label><span v-text="form[item].label || item"></span><span v-if="form[item].required === false"> ({{ $ts.optional }})</span></template>
					<option v-for="item_ in form[item].enum" :key="item_.value" :value="item_.value">{{ item_.label }}</option>
				</FormSelect>
				<FormRadios v-else-if="form[item].type === 'radio'" v-model="values[item]" class="_formBlock">
					<template #label><span v-text="form[item].label || item"></span><span v-if="form[item].required === false"> ({{ $ts.optional }})</span></template>
					<option v-for="item_ in form[item].options" :key="item_.value" :value="item_.value">{{ item_.label }}</option>
				</FormRadios>
				<FormRange v-else-if="form[item].type === 'range'" v-model="values[item]" :min="form[item].min" :max="form[item].max" :step="form[item].step" :text-converter="form[item].textConverter" class="_formBlock">
					<template #label><span v-text="form[item].label || item"></span><span v-if="form[item].required === false"> ({{ $ts.optional }})</span></template>
					<template v-if="form[item].description" #caption>{{ form[item].description }}</template>
				</FormRange>
				<MkButton v-else-if="form[item].type === 'button'" class="_formBlock" @click="form[item].action($event, values)">
					<span v-text="form[item].content || item"></span>
				</MkButton>
			</template>
		</div>
	</MkSpacer>
</XModalWindow>
</template>

<script lang="ts">
import { defineComponent } from 'vue';
import FormInput from './form/input.vue';
import FormTextarea from './form/textarea.vue';
import FormSwitch from './form/switch.vue';
import FormSelect from './form/select.vue';
import FormRange from './form/range.vue';
import MkButton from './MkButton.vue';
import FormRadios from './form/radios.vue';
import XModalWindow from '@/components/MkModalWindow.vue';

export default defineComponent({
	components: {
		XModalWindow,
		FormInput,
		FormTextarea,
		FormSwitch,
		FormSelect,
		FormRange,
		MkButton,
		FormRadios,
	},

	props: {
		title: {
			type: String,
			required: true,
		},
		form: {
			type: Object,
			required: true,
		},
	},

	emits: ['done'],

	data() {
		return {
			values: {},
		};
	},

	created() {
		for (const item in this.form) {
			this.values[item] = this.form[item].default ?? null;
		}
	},

	methods: {
		ok() {
			this.$emit('done', {
				result: this.values,
			});
			this.$refs.dialog.close();
		},

		cancel() {
			this.$emit('done', {
				canceled: true,
			});
			this.$refs.dialog.close();
		},
	},
});
</script>

<style lang="scss" scoped>
.xkpnjxcv {

}
</style>
