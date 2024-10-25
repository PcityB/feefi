import React                            from "react"
import { injectIntl, FormattedMessage, FormattedNumber } from 'react-intl';
import TrendIcon                        from "../widgets/trend-icon"
import AbstractComponent                from "../widgets/abstract-component"
import LoadingImage                     from "../widgets/loading-image"

const keys = new Set([
  "formattedBalance", "formattedChangesFromPreviousDay",
  "formattedChangeRatioFromPreviousDay", "changesFromPreviousDay"
]);

class BalancePanel extends AbstractComponent {

  constructor(props) {
    super(props);
    this.state = {};
  }

  componentWillMount() {
    this.registerPropertyChangeListener(this.props.model, keys);
    const state = this.collectInitialState(this.props.model, keys);
    this.setState(state);
  }

  render() {
    const style = this.props.visibleTradingSummary
      ? { width: "calc(67% - 32px)"} : { width: "100%" };
    return (
      <div key="balance panel" className="balance panel" style={style}>
        <div className="title">
          <span className="icon md-account-balance"></span>
          <span className="text"><FormattedMessage id="accounts.BalancePanel.title" /></span>
        </div>
        {this.createContent()}
      </div>
    );
  }

  createContent() {
    if (!this.state.formattedBalance) {
      return <div className="center-information loading">
        <LoadingImage left={-20} />
      </div>;
    }
    return [
      <div key="balance" className="balance">
        <FormattedNumber
          value={this.state.balance}
          style="currency"
          currency={this.props.intl.formatMessage({id: 'common.currency'})}
        />
      </div>,
      <div key="changes-from-previous-day" className="changes-from-previous-day">
        {this.createPriceAndRatio()}
        <TrendIcon value={this.state.changesFromPreviousDay} />
      </div>
    ];
  }

  createPriceAndRatio() {
    const { formatMessage, formatNumber } = this.props.intl;
    let result = `${formatMessage({id: 'accounts.BalancePanel.dayBeforeRatio'})}: `;
    result += formatNumber(this.state.changesFromPreviousDay, {
      style: 'currency',
      currency: formatMessage({id: 'common.currency'})
    });
    result += " ( " + (this.state.formattedChangeRatioFromPreviousDay || "-%") + " )";
    return result;
  }
}

export default injectIntl(BalancePanel);
