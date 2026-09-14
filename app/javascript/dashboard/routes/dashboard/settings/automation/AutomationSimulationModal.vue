<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  automation: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['close']);
const { t } = useI18n();

// Actions that would reach the customer. These are never executed in a dry run.
const CUSTOMER_FACING_ACTIONS = [
  'send_message',
  'send_attachment',
  'send_email_transcript',
];

const simulationChannel = ref('Channel::WebWidget');
const simulationPriority = ref('urgent');
const simulationStatus = ref('open');
const simulationMessage = ref('');

const isSimulated = ref(false);
const simulationTrace = ref([]);
const matched = ref(false);

// Mirrors the attribute keys the automation builder exposes for conversations.
const simulatedConversation = computed(() => ({
  status: simulationStatus.value,
  priority: simulationPriority.value,
  inbox_id: simulationChannel.value,
  message_type: 'incoming',
  content: simulationMessage.value,
}));

const normalise = value => {
  if (value === null || value === undefined) return '';
  return String(value).trim().toLowerCase();
};

const toComparableList = values => {
  if (Array.isArray(values)) return values.map(normalise).filter(Boolean);
  if (values === null || values === undefined || values === '') return [];
  return [normalise(values)];
};

/**
 * Evaluates a single automation condition against the simulated conversation.
 * Operators mirror `operators.js`, which mirrors the backend filter operators.
 */
const evaluateCondition = condition => {
  const actual = normalise(
    simulatedConversation.value[condition.attribute_key]
  );
  const expected = toComparableList(condition.values);
  const hasValue = actual !== '';

  switch (condition.filter_operator) {
    case 'equal_to':
      return expected.includes(actual);
    case 'not_equal_to':
      return !expected.includes(actual);
    case 'contains':
      return expected.some(value => actual.includes(value));
    case 'does_not_contain':
      return !expected.some(value => actual.includes(value));
    case 'starts_with':
      return expected.some(value => actual.startsWith(value));
    case 'is_present':
      return hasValue;
    case 'is_not_present':
      return !hasValue;
    default:
      // Unsupported operator (date/number ranges) cannot be simulated offline.
      return null;
  }
};

const describeCondition = condition =>
  `${condition.attribute_key} ${condition.filter_operator} ${toComparableList(condition.values).join(', ')}`;

const runSimulation = () => {
  if (!props.automation) return;

  const trace = [];
  trace.push({
    type: 'trigger',
    title: t('AUTOMATION.SIMULATION.TRACE.TRIGGER'),
    detail: props.automation.event_name,
    status: 'success',
  });

  const conditions = props.automation.conditions || [];
  const results = conditions.map(condition => ({
    condition,
    result: evaluateCondition(condition),
  }));

  results.forEach(({ condition, result }, index) => {
    let status = 'failure';
    if (result === true) status = 'success';
    if (result === null) status = 'warning';

    trace.push({
      type: 'condition',
      title: t('AUTOMATION.SIMULATION.TRACE.CONDITION', {
        index: index + 1,
        description: describeCondition(condition),
      }),
      detail:
        result === null
          ? t('AUTOMATION.SIMULATION.TRACE.UNSUPPORTED_OPERATOR')
          : t(
              result
                ? 'AUTOMATION.SIMULATION.TRACE.CONDITION_MATCH'
                : 'AUTOMATION.SIMULATION.TRACE.CONDITION_NO_MATCH'
            ),
      status,
    });
  });

  // Chatwoot evaluates conditions with the operator recorded on each condition.
  // `query_operator` is 'and'/'or' and lives on the preceding condition.
  const evaluated = results.filter(({ result }) => result !== null);
  const usesOr = conditions.some(
    condition => normalise(condition.query_operator) === 'or'
  );

  let conditionsPass;
  if (!evaluated.length) {
    conditionsPass = conditions.length === 0;
  } else if (usesOr) {
    conditionsPass = evaluated.some(({ result }) => result);
  } else {
    conditionsPass = evaluated.every(({ result }) => result);
  }

  matched.value = conditionsPass;

  trace.push({
    type: 'summary',
    title: t('AUTOMATION.SIMULATION.TRACE.SUMMARY'),
    detail: t(
      conditionsPass
        ? 'AUTOMATION.SIMULATION.TRACE.SUMMARY_MATCH'
        : 'AUTOMATION.SIMULATION.TRACE.SUMMARY_NO_MATCH',
      {
        matched: evaluated.filter(({ result }) => result).length,
        total: conditions.length,
      }
    ),
    status: conditionsPass ? 'success' : 'failure',
  });

  if (conditionsPass) {
    const actions = props.automation.actions || [];
    actions.forEach((action, index) => {
      const isCustomerFacing = CUSTOMER_FACING_ACTIONS.includes(
        action.action_name
      );
      trace.push({
        type: 'action',
        title: t('AUTOMATION.SIMULATION.TRACE.ACTION', {
          index: index + 1,
          name: action.action_name,
        }),
        detail: t(
          isCustomerFacing
            ? 'AUTOMATION.SIMULATION.TRACE.ACTION_SUPPRESSED'
            : 'AUTOMATION.SIMULATION.TRACE.ACTION_DRY_RUN'
        ),
        status: isCustomerFacing ? 'warning' : 'success',
      });
    });

    trace.push({
      type: 'result',
      title: t('AUTOMATION.SIMULATION.TRACE.COMPLETE'),
      detail: t('AUTOMATION.SIMULATION.TRACE.COMPLETE_DETAIL', {
        count: actions.length,
      }),
      status: 'complete',
    });
  } else {
    trace.push({
      type: 'result',
      title: t('AUTOMATION.SIMULATION.TRACE.COMPLETE'),
      detail: t('AUTOMATION.SIMULATION.TRACE.SKIPPED_ACTIONS'),
      status: 'failure',
    });
  }

  simulationTrace.value = trace;
  isSimulated.value = true;
};
</script>

<template>
  <Dialog
    :title="
      $t('AUTOMATION.SIMULATION.TITLE', {
        name: automation?.name || $t('AUTOMATION.SIMULATION.FALLBACK_NAME'),
      })
    "
    :description="$t('AUTOMATION.SIMULATION.DESCRIPTION')"
    @close="emit('close')"
  >
    <div class="space-y-4 text-xs text-slate-300">
      <!-- Input Parameters -->
      <div
        class="rounded-lg bg-slate-900 border border-slate-800 p-3.5 space-y-3"
      >
        <span class="font-semibold text-white block">
          {{ $t('AUTOMATION.SIMULATION.INPUTS') }}
        </span>

        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="text-[11px] text-slate-400 block mb-1">
              {{ $t('AUTOMATION.SIMULATION.STATUS') }}
            </label>
            <select
              v-model="simulationStatus"
              class="w-full rounded border border-slate-800 bg-slate-950 px-2 py-1 text-xs text-slate-200"
            >
              <option value="open">
                {{ $t('AUTOMATION.SIMULATION.STATUS_OPTIONS.OPEN') }}
              </option>
              <option value="pending">
                {{ $t('AUTOMATION.SIMULATION.STATUS_OPTIONS.PENDING') }}
              </option>
              <option value="snoozed">
                {{ $t('AUTOMATION.SIMULATION.STATUS_OPTIONS.SNOOZED') }}
              </option>
              <option value="resolved">
                {{ $t('AUTOMATION.SIMULATION.STATUS_OPTIONS.RESOLVED') }}
              </option>
            </select>
          </div>

          <div>
            <label class="text-[11px] text-slate-400 block mb-1">
              {{ $t('AUTOMATION.SIMULATION.PRIORITY') }}
            </label>
            <select
              v-model="simulationPriority"
              class="w-full rounded border border-slate-800 bg-slate-950 px-2 py-1 text-xs text-slate-200"
            >
              <option value="urgent">
                {{ $t('AUTOMATION.SIMULATION.PRIORITY_OPTIONS.URGENT') }}
              </option>
              <option value="high">
                {{ $t('AUTOMATION.SIMULATION.PRIORITY_OPTIONS.HIGH') }}
              </option>
              <option value="medium">
                {{ $t('AUTOMATION.SIMULATION.PRIORITY_OPTIONS.MEDIUM') }}
              </option>
              <option value="low">
                {{ $t('AUTOMATION.SIMULATION.PRIORITY_OPTIONS.LOW') }}
              </option>
            </select>
          </div>
        </div>

        <div>
          <label class="text-[11px] text-slate-400 block mb-1">
            {{ $t('AUTOMATION.SIMULATION.SAMPLE_MESSAGE') }}
          </label>
          <input
            v-model="simulationMessage"
            type="text"
            :placeholder="$t('AUTOMATION.SIMULATION.SAMPLE_PLACEHOLDER')"
            class="w-full rounded border border-slate-800 bg-slate-950 px-2.5 py-1 text-xs text-slate-200"
          />
        </div>

        <div class="flex justify-end pt-1">
          <NextButton
            icon="i-lucide-play"
            color="blue"
            xs
            :label="$t('AUTOMATION.SIMULATION.RUN')"
            :disabled="!automation"
            @click="runSimulation"
          />
        </div>
      </div>

      <!-- Execution Trace -->
      <div v-if="isSimulated" class="space-y-2">
        <div class="flex items-center justify-between">
          <span class="font-semibold text-white">
            {{ $t('AUTOMATION.SIMULATION.TRACE_TITLE') }}
          </span>
          <span
            class="rounded-full px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide"
            :class="
              matched
                ? 'bg-emerald-500/15 text-emerald-400'
                : 'bg-slate-800 text-slate-400'
            "
          >
            {{
              matched
                ? $t('AUTOMATION.SIMULATION.RESULT_MATCH')
                : $t('AUTOMATION.SIMULATION.RESULT_NO_MATCH')
            }}
          </span>
        </div>
        <div
          class="space-y-2 max-h-60 overflow-y-auto rounded-lg bg-slate-900 border border-slate-800 p-3 font-mono text-[11px]"
        >
          <div
            v-for="(step, index) in simulationTrace"
            :key="index"
            class="p-2 rounded border"
            :class="{
              'bg-slate-950 border-slate-800 text-slate-300':
                step.status === 'success',
              'bg-amber-950/40 border-amber-800/60 text-amber-300':
                step.status === 'warning',
              'bg-rose-950/40 border-rose-800/60 text-rose-300':
                step.status === 'failure',
              'bg-emerald-950/40 border-emerald-800/60 text-emerald-300':
                step.status === 'complete',
            }"
          >
            <div class="font-semibold">{{ step.title }}</div>
            <div class="text-[10px] opacity-90 mt-0.5">{{ step.detail }}</div>
          </div>
        </div>
      </div>
    </div>
  </Dialog>
</template>
