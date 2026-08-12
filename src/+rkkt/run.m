function project = run()            %输出project，输入无
%RUN Execute the complete seven-day Stage B-2C package workflow.
%这个函数是整个项目的顶层总入口函数，按顺序调用两个工作流函数
%当前正式入口直接调用包含水量约束的Stage B-2C完整工作流。
project = rkkt.workflows.stageB2C();
end
