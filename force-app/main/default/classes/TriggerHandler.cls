/**
 * @description Virtual base class for trigger handlers providing event routing and bypass capabilities.
 */
public virtual class TriggerHandler {

    private static Set<String> bypassedHandlers = new Set<String>();

    public void run() {
        if (!validateRun()) {
            return;
        }

        switch on Trigger.operationType {
            when BEFORE_INSERT {
                this.beforeInsert();
            }
            when BEFORE_UPDATE {
                this.beforeUpdate();
            }
            when BEFORE_DELETE {
                this.beforeDelete();
            }
            when AFTER_INSERT {
                this.afterInsert();
            }
            when AFTER_UPDATE {
                this.afterUpdate();
            }
            when AFTER_DELETE {
                this.afterDelete();
            }
            when AFTER_UNDELETE {
                this.afterUndelete();
            }
        }
    }

    public static void bypass(String handlerName) {
        bypassedHandlers.add(handlerName);
    }

    public static void clearBypass(String handlerName) {
        bypassedHandlers.remove(handlerName);
    }

    public static Boolean isBypassed(String handlerName) {
        return bypassedHandlers.contains(handlerName);
    }

    public static void clearAllBypasses() {
        bypassedHandlers.clear();
    }

    private Boolean validateRun() {
        if (!Trigger.isExecuting) {
            return false;
        }
        String handlerName = this.getHandlerName();
        if (isBypassed(handlerName)) {
            return false;
        }
        return true;
    }

    protected virtual String getHandlerName() {
        return String.valueOf(this).split(':')[0];
    }

    protected virtual void beforeInsert() {}
    protected virtual void beforeUpdate() {}
    protected virtual void beforeDelete() {}
    protected virtual void afterInsert() {}
    protected virtual void afterUpdate() {}
    protected virtual void afterDelete() {}
    protected virtual void afterUndelete() {}
}
