self: super:
{
  lima = super.lima.override {
    withAdditionalGuestAgents = true;
  };
}
